#include <search_users_handler.hpp>
#include <utils_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

SearchUsersHandler::SearchUsersHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string SearchUsersHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& query = request.GetArg("query");

  if (query.empty()) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Search query is required");
  }

  if (query.length() < 2) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Search query must be at least 2 characters");
  }

  try {
    std::string search_pattern = "%" + query + "%";

    auto result = [&]() {
      return pg_cluster_->Execute(
          userver::storages::postgres::ClusterHostType::kSlave,
          "SELECT user_id, name FROM seagull_schema.users WHERE name ILIKE $1 "
          "LIMIT 10",
          search_pattern);
    }();

    userver::formats::json::ValueBuilder users(
        userver::formats::common::Type::kArray);

    for (const auto& row : result) {
      userver::formats::json::ValueBuilder user;
      user["user_id"] = row["user_id"].As<int>();
      user["name"] = row["name"].As<std::string>();
      users.PushBack(std::move(user));
    }

    userver::formats::json::ValueBuilder resp;
    resp["query"] = query;
    resp["count"] = users.GetSize();
    resp["users"] = std::move(users);

    response.SetStatus(userver::server::http::HttpStatus::kOk);
    return userver::formats::json::ToString(resp.ExtractValue());

  } catch (const std::exception& e) {
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Database error occurred");
  }
}

}  // namespace myservice
