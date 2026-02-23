#include <login_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

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

  const auto body = userver::formats::json::FromString(request.RequestBody());
  const auto login = body["login"].As<std::string>("");
  const auto password_hash = body["password_hash"].As<std::string>("");

  const auto result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kMaster,
      "SELECT user_id FROM seagull_schema.users WHERE login = $1 AND password_hash = $2",
      login, password_hash);
  userver::formats::json::ValueBuilder resp;
  if (!result.IsEmpty()) {
    resp["user_id"] = result[0]["user_id"].As<int>();
  }
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
