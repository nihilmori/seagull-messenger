#include <get_user_profile_handler.hpp>
#include <utils_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

GetUserProfileHandler::GetUserProfileHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string GetUserProfileHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const int user_id = request["user_id"].As<int>(0);

  if (user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id must be a positive integer");
  }

  try {
    auto result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT user_id, login, name, bio FROM seagull_schema.users WHERE user_id = $1",
        user_id);

    if (result.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      return utils_handler::MakeErrorJson("User not found");
    }

    const auto& row = result[0];
    
    userver::formats::json::ValueBuilder resp;
    resp["user_id"] = row["user_id"].As<int>();
    resp["login"] = row["login"].As<std::string>();
    resp["name"] = row["name"].As<std::string>();
    resp["bio"] = row["bio"].As<std::string>();

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());

  } catch (const std::exception& e) {
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Database error occurred");
  }
}

}  // namespace myservice
