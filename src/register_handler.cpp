#include <register_handler.hpp>
#include <utils_handler.hpp>

#include <userver/crypto/hash.hpp>
#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

RegisterHandler::RegisterHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string RegisterHandler::HandleRequestThrow(
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

  const auto login = body["login"].As<std::string>("");
  const auto password = body["password"].As<std::string>("");
  const auto name = body["name"].As<std::string>("");

  if (utils_handler::IsBlank(login)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'login' is required");
  }

  if (!utils_handler::IsCorrectPassword(password)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'password' is not correct");
  }

  if (utils_handler::IsBlank(name)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'name' is required");
  }

  const auto salt = utils_handler::GenerateSalt();
  const auto password_hash = userver::crypto::hash::Sha256(
      salt + password, userver::crypto::hash::OutputEncoding::kBase64);

  try {
    const auto result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kMaster,
        "INSERT INTO seagull_schema.users(login, password_hash, salt, name) "
        "VALUES($1, $2, $3, $4) "
        "ON CONFLICT (login) DO NOTHING "
        "RETURNING user_id, login, name",
        login, password_hash, salt, name);

    if (result.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kConflict);
      return utils_handler::MakeErrorJson(
          "User with this login already exists");
    }

    const auto row = result[0];
    userver::formats::json::ValueBuilder resp;
    resp["user_id"] = row["user_id"].As<int>();
    resp["login"] = row["login"].As<std::string>();
    resp["name"] = row["name"].As<std::string>();

    response.SetStatus(userver::server::http::HttpStatus::kCreated);
    return userver::formats::json::ToString(resp.ExtractValue());
  } catch (const std::exception&) {
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Database error occurred");
  }
}

}  // namespace myservice
