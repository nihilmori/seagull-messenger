#include "update_user_handler.hpp"

#include <utils_handler.hpp>

#include <userver/crypto/hash.hpp>
#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>
#include <userver/storages/postgres/transaction.hpp>

namespace myservice {

UpdateUserHandler::UpdateUserHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string UpdateUserHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  userver::formats::json::Value body;
  try {
    body = userver::formats::json::FromString(request.RequestBody());
  } catch (const std::exception&) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Invalid JSON body");
  }

  const int user_id = body["user_id"].As<int>(0);
  if (user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Field 'user_id' must be a positive integer");
  }

  const bool has_name = body.HasMember("name");
  const bool has_bio = body.HasMember("bio");
  const bool has_login = body.HasMember("login");
  const bool has_new_password = body.HasMember("new_password");

  if (!has_name && !has_bio && !has_login && !has_new_password) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "At least one field to update is required: name, bio, login, "
        "new_password");
  }

  const auto name = has_name ? body["name"].As<std::string>("") : "";
  const auto bio = has_bio ? body["bio"].As<std::string>("") : "";
  const auto new_login = has_login ? body["login"].As<std::string>("") : "";
  const auto new_password =
      has_new_password ? body["new_password"].As<std::string>("") : "";
  const auto current_password = body["current_password"].As<std::string>("");

  if (has_name && utils_handler::IsBlank(name)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'name' must not be empty");
  }

  if (has_login && utils_handler::IsBlank(new_login)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'login' must not be empty");
  }

  if (has_new_password) {
    const auto pwd_error = utils_handler::ValidatePassword(new_password);
    if (pwd_error.has_value()) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson(*pwd_error);
    }
    if (utils_handler::IsBlank(current_password)) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson(
          "Field 'current_password' is required when changing password");
    }
  }

  auto transaction =
      pg_cluster_->Begin(userver::storages::postgres::ClusterHostType::kMaster,
                         userver::storages::postgres::TransactionOptions{});

  try {
    const auto user_result = transaction.Execute(
        "SELECT login, name, bio, salt, password_hash FROM "
        "seagull_schema.users WHERE user_id = $1",
        user_id);
    if (user_result.IsEmpty()) {
      transaction.Rollback();
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      return utils_handler::MakeErrorJson("User not found");
    }

    const auto& row = user_result[0];

    if (has_new_password) {
      const auto salt = row["salt"].As<std::string>();
      const auto stored_hash = row["password_hash"].As<std::string>();
      const auto check_hash = userver::crypto::hash::Sha256(
          salt + current_password,
          userver::crypto::hash::OutputEncoding::kBase64);
      if (check_hash != stored_hash) {
        transaction.Rollback();
        response.SetStatus(userver::server::http::HttpStatus::kForbidden);
        return utils_handler::MakeErrorJson("Current password is incorrect");
      }
    }

    if (has_login) {
      const auto login_check = transaction.Execute(
          "SELECT 1 FROM seagull_schema.users WHERE login = $1 AND "
          "user_id != $2",
          new_login, user_id);
      if (!login_check.IsEmpty()) {
        transaction.Rollback();
        response.SetStatus(userver::server::http::HttpStatus::kConflict);
        return utils_handler::MakeErrorJson("Login is already taken");
      }
    }

    if (has_name) {
      transaction.Execute(
          "UPDATE seagull_schema.users SET name = $1 WHERE user_id = $2", name,
          user_id);
    }
    if (has_bio) {
      transaction.Execute(
          "UPDATE seagull_schema.users SET bio = $1 WHERE user_id = $2", bio,
          user_id);
    }
    if (has_login) {
      transaction.Execute(
          "UPDATE seagull_schema.users SET login = $1 WHERE user_id = $2",
          new_login, user_id);
    }
    if (has_new_password) {
      const auto new_salt = utils_handler::GenerateSalt();
      const auto new_hash = userver::crypto::hash::Sha256(
          new_salt + new_password,
          userver::crypto::hash::OutputEncoding::kBase64);
      transaction.Execute(
          "UPDATE seagull_schema.users SET salt = $1, password_hash = $2 "
          "WHERE user_id = $3",
          new_salt, new_hash, user_id);
    }

    const auto updated = transaction.Execute(
        "SELECT login, name, bio FROM seagull_schema.users WHERE user_id = $1",
        user_id);

    transaction.Commit();

    userver::formats::json::ValueBuilder resp;
    resp["user_id"] = user_id;
    resp["login"] = updated[0]["login"].As<std::string>();
    resp["name"] = updated[0]["name"].As<std::string>();
    resp["bio"] = updated[0]["bio"].As<std::string>();

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());
  } catch (const std::exception&) {
    transaction.Rollback();
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Failed to update user");
  }
}

}  // namespace myservice
