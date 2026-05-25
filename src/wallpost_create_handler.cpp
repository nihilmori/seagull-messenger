#include "wallpost_create_handler.hpp"

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>

#include "utils_handler.hpp"

namespace myservice {

WallPostCreateHandler::WallPostCreateHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string WallPostCreateHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
    auto& response = request.GetHttpResponse();
    response.SetContentType("application/json");

    const auto& wall_owner_id_str = request.GetPathArg("user_id");
    int wall_owner_id = 0;
    if (!utils_handler::TryParseInt(wall_owner_id_str, wall_owner_id) || wall_owner_id <= 0) {
        response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
        return utils_handler::MakeErrorJson("Invalid wall_owner_id. Must be a positive integer");
    }

    userver::formats::json::Value body;
    try {
        body = userver::formats::json::FromString(request.RequestBody());
    } catch (const std::exception&) {
        response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
        return utils_handler::MakeErrorJson("Invalid JSON format");
    }

    int author_id = body["author_id"].As<int>(0);
    std::string content = body["content"].As<std::string>("");

    if (author_id <= 0) {
        response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
        return utils_handler::MakeErrorJson("author_id must be a positive integer");
    }

    if (content.empty()) {
        response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
        return utils_handler::MakeErrorJson("content cannot be empty");
    }

    if (content.length() > 1000) {
        response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
        return utils_handler::MakeErrorJson("content must not exceed 1000 characters");
    }

    try {
	auto users_result = pg_cluster_->Execute(
    	    userver::storages::postgres::ClusterHostType::kSlave,
    	    "SELECT user_id, name FROM seagull_schema.users WHERE user_id IN ($1, $2)",
    	    wall_owner_id, author_id);

	    auto expected_count = (wall_owner_id == author_id) ? 1 : 2;

	if (users_result.Size() != static_cast<size_t>(expected_count)) {
	    response.SetStatus(userver::server::http::HttpStatus::kNotFound);
	    return utils_handler::MakeErrorJson("User not found");
	}

	std::string author_name;
        for (const auto& row : users_result) {
            int user_id = row["user_id"].As<int>();
            if (user_id == author_id) {
                author_name = row["name"].As<std::string>();
                break;
            }
        }

        auto insert_result = pg_cluster_->Execute(
            userver::storages::postgres::ClusterHostType::kMaster,
            "INSERT INTO seagull_schema.wall_posts (user_id, author_id, content) "
            "VALUES ($1, $2, $3) "
            "RETURNING post_id, created_at",
            wall_owner_id, author_id, content);

        if (insert_result.IsEmpty()) {
            response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
            return utils_handler::MakeErrorJson("Failed to create post");
        }

        int post_id = insert_result[0]["post_id"].As<int>();
        std::string created_at = insert_result[0]["created_at"].As<std::string>();

        userver::formats::json::ValueBuilder response_body;
        response_body["post_id"] = post_id;
        response_body["wall_owner_id"] = wall_owner_id;
        response_body["author_id"] = author_id;
        response_body["author_name"] = author_name;
        response_body["content"] = content;
        response_body["created_at"] = created_at;

        response.SetStatus(userver::server::http::HttpStatus::kCreated);
        return userver::formats::json::ToString(response_body.ExtractValue());

    } catch (const std::exception& e) {
        response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
        return utils_handler::MakeErrorJson(std::string("Database error: ") + e.what());
    }
}

}  // namespace myservice
