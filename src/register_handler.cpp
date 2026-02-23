#include <register_handler.hpp>

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

  const auto body = userver::formats::json::FromString(request.RequestBody());
  const auto login = body["login"].As<std::string>("");
  const auto password_hash = body["password_hash"].As<std::string>("");
  const auto name = body["name"].As<std::string>("");

  const auto result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kMaster,
      "INSERT INTO seagull_schema.users(login, password_hash, name) "
      "VALUES($1, $2, $3) RETURNING user_id, login, name",
      login, password_hash, name);
  const auto row = result[0];
  userver::formats::json::ValueBuilder resp;
  resp["user_id"] = row["user_id"].As<int>();
  resp["login"] = row["login"].As<std::string>();
  resp["name"] = row["name"].As<std::string>();
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
