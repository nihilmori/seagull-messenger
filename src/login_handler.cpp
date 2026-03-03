#include <login_handler.hpp>
#include <utils_handler.hpp>

#include <string_view>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>
#include <userver/crypto/hash.hpp>

namespace myservice {

LoginHandler::LoginHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string LoginHandler::HandleRequestThrow(
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

  if (utils_handler::IsBlank(login)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'login' is required");
  }

  if (utils_handler::IsBlank(password)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'password' is required");
  }

  auto password_hash = userver::crypto::hash::Sha256(
    password,
    userver::crypto::hash::OutputEncoding::kBase64
  );

  const auto result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kMaster,
      "SELECT user_id, login, name FROM seagull_schema.users WHERE login = $1 "
      "AND password_hash = $2",
      login, password_hash);

  if (result.IsEmpty()) {
    response.SetStatus(userver::server::http::HttpStatus::kUnauthorized);
    return utils_handler::MakeErrorJson("Invalid login or password");
  }

  userver::formats::json::ValueBuilder resp;
  resp["user_id"] = result[0]["user_id"].As<int>();
  resp["login"] = result[0]["login"].As<std::string>();
  resp["name"] = result[0]["name"].As<std::string>();

  response.SetStatus(userver::server::http::HttpStatus::kOk);
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
