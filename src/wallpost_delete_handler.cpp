#include "wallpost_delete_handler.hpp"

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>

#include "utils_handler.hpp"

namespace myservice {

WallPostDeleteHandler::WallPostDeleteHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string WallPostDeleteHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
    auto& response = request.GetHttpResponse();
    response.SetContentType("application/json");

    const auto& post_id_str = request.GetPathArg("post_id");
    int post_id = 0;
    if (!utils_handler::TryParseInt(post_id_str, post_id) || post_id <= 0) {
        response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
        return utils_handler::MakeErrorJson("post_id must be a positive integer");
    }

    userver::formats::json::Value body;
    try {
        body = userver::formats::json::FromString(request.RequestBody());
    } catch (const std::exception&) {
        body = userver::formats::json::Value{};
    }

    int requester_id = 0;
    
    const auto& user_id_arg = request.GetArg("user_id");
    if (!user_id_arg.empty()) {
        utils_handler::TryParseInt(user_id_arg, requester_id);
    }
    
    if (requester_id <= 0) {
        requester_id = body["user_id"].As<int>(0);
    }
    
    if (requester_id <= 0) {
        requester_id = body["requester_id"].As<int>(0);
    }

    if (requester_id <= 0) {
        response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
        return utils_handler::MakeErrorJson("user_id or requester_id must be a positive integer");
    }

    try {
        auto post_info = pg_cluster_->Execute(
            userver::storages::postgres::ClusterHostType::kSlave,
            "SELECT user_id, author_id, is_deleted FROM seagull_schema.wall_posts "
            "WHERE post_id = $1",
            post_id);
        
        if (post_info.IsEmpty()) {
            response.SetStatus(userver::server::http::HttpStatus::kNotFound);
            return utils_handler::MakeErrorJson("Post not found");
        }
        
        int wall_owner_id = post_info[0]["user_id"].As<int>();
        int author_id = post_info[0]["author_id"].As<int>();
        bool is_deleted = post_info[0]["is_deleted"].As<bool>();
        
        if (is_deleted) {
            response.SetStatus(userver::server::http::HttpStatus::kNotFound);
            return utils_handler::MakeErrorJson("Post already deleted");
        }
        
        if (requester_id != author_id && requester_id != wall_owner_id) {
            response.SetStatus(userver::server::http::HttpStatus::kForbidden);
            return utils_handler::MakeErrorJson("You don't have permission to delete this post");
        }
        
        pg_cluster_->Execute(
            userver::storages::postgres::ClusterHostType::kMaster,
            "UPDATE seagull_schema.wall_posts "
            "SET is_deleted = true, updated_at = CURRENT_TIMESTAMP "
            "WHERE post_id = $1",
            post_id);
        
        userver::formats::json::ValueBuilder response_body;
        response_body["post_id"] = post_id;
        response_body["deleted"] = true;
        response_body["message"] = "Post successfully deleted";
        
        response.SetStatus(userver::server::http::HttpStatus::kOk);
        return userver::formats::json::ToString(response_body.ExtractValue());
        
    } catch (const std::exception& e) {
        response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
        return utils_handler::MakeErrorJson(std::string("Database error: ") + e.what());
    }
}

}  // namespace myservice
