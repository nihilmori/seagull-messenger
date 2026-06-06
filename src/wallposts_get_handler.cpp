#include "wallposts_get_handler.hpp"

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>

#include "utils_handler.hpp"

namespace myservice {

WallPostsGetHandler::WallPostsGetHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string WallPostsGetHandler::HandleRequestThrow(
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

    int limit = 50;
    int offset = 0;
    
    const auto& limit_arg = request.GetArg("limit");
    if (!limit_arg.empty()) {
        if (!utils_handler::TryParseInt(limit_arg, limit) || limit < 1 || limit > 200) {
            response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
            return utils_handler::MakeErrorJson("limit must be between 1 and 200");
        }
    }
    
    const auto& offset_arg = request.GetArg("offset");
    if (!offset_arg.empty()) {
        if (!utils_handler::TryParseInt(offset_arg, offset) || offset < 0) {
            response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
            return utils_handler::MakeErrorJson("offset must be a non-negative integer");
        }
    }

    try {
        auto user_check = pg_cluster_->Execute(
            userver::storages::postgres::ClusterHostType::kSlave,
            "SELECT user_id, name FROM seagull_schema.users WHERE user_id = $1",
            wall_owner_id);
        
        if (user_check.IsEmpty()) {
            response.SetStatus(userver::server::http::HttpStatus::kNotFound);
            return utils_handler::MakeErrorJson("User not found");
        }
        
        std::string wall_owner_name = user_check[0]["name"].As<std::string>();

        auto posts_result = pg_cluster_->Execute(
            userver::storages::postgres::ClusterHostType::kSlave,
            "SELECT wp.post_id, wp.content, "
            "       to_char(wp.created_at AT TIME ZONE 'Europe/Moscow', 'DD.MM.YYYY HH24:MI:SS') AS created_at, "
            "       to_char(wp.updated_at AT TIME ZONE 'Europe/Moscow', 'DD.MM.YYYY HH24:MI:SS') AS updated_at, "
            "       u.user_id as author_id, u.name as author_name "
            "FROM seagull_schema.wall_posts wp "
            "JOIN seagull_schema.users u ON wp.author_id = u.user_id "
            "WHERE wp.user_id = $1 AND wp.is_deleted = false "
            "ORDER BY wp.created_at DESC "
            "LIMIT $2 OFFSET $3",
            wall_owner_id, limit, offset);

        userver::formats::json::ValueBuilder response_body;
        response_body["wall_owner_id"] = wall_owner_id;
        response_body["wall_owner_name"] = wall_owner_name;
        response_body["limit"] = limit;
        response_body["offset"] = offset;
        response_body["count"] = static_cast<int>(posts_result.Size());
        
        userver::formats::json::ValueBuilder posts_array = userver::formats::json::Type::kArray;
        
        for (const auto& row : posts_result) {
    	    userver::formats::json::ValueBuilder post;
    	    post["post_id"] = row["post_id"].As<int>();
    	    post["content"] = row["content"].As<std::string>();
    	    post["author_id"] = row["author_id"].As<int>();
    	    post["author_name"] = row["author_name"].As<std::string>();
    	    post["created_at"] = row["created_at"].As<std::string>();
    	    post["updated_at"] = row["updated_at"].As<std::string>();
    
    	    posts_array.PushBack(post.ExtractValue());
	}   

        response_body["posts"] = posts_array.ExtractValue();

        response.SetStatus(userver::server::http::HttpStatus::kOk);
        return userver::formats::json::ToString(response_body.ExtractValue());
        
    } catch (const std::exception& e) {
        response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
        return utils_handler::MakeErrorJson(std::string("Database error: ") + e.what());
    }
}

}  // namespace myservice
