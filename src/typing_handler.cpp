#include "typing_handler.hpp"
#include "utils_handler.hpp"

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

TypingHandler::TypingHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string TypingHandler::HandleRequestThrow(
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
  const int chat_id = body["chat_id"].As<int>(-1);
  const bool is_typing = body["is_typing"].As<bool>(false);

  if (user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id must be a positive integer");
  }

  if (chat_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("chat_id must be a positive integer");
  }

  const auto user_check = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kSlave,
      "SELECT 1 FROM seagull_schema.users WHERE user_id = $1", user_id);

  if (user_check.IsEmpty()) {
    response.SetStatus(userver::server::http::HttpStatus::kNotFound);
    return utils_handler::MakeErrorJson("User not found");
  }

  const auto chat_check = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kSlave,
      "SELECT 1 FROM seagull_schema.chats WHERE chat_id = $1", chat_id);

  if (chat_check.IsEmpty()) {
    response.SetStatus(userver::server::http::HttpStatus::kNotFound);
    return utils_handler::MakeErrorJson("Chat not found");
  }

  const auto participant_check =
      pg_cluster_->Execute(userver::storages::postgres::ClusterHostType::kSlave,
                           "SELECT 1 FROM seagull_schema.chat_users WHERE "
                           "chat_id = $1 AND user_id = $2",
                           chat_id, user_id);

  if (participant_check.IsEmpty()) {
    response.SetStatus(userver::server::http::HttpStatus::kForbidden);
    return utils_handler::MakeErrorJson(
        "User is not a participant of this chat");
  }

  pg_cluster_->Execute(userver::storages::postgres::ClusterHostType::kMaster,
                       "INSERT INTO seagull_schema.typing_status (chat_id, "
                       "user_id, is_typing, updated_at) "
                       "VALUES ($1, $2, $3, CURRENT_TIMESTAMP) "
                       "ON CONFLICT (chat_id, user_id) DO UPDATE SET "
                       "is_typing = $3, updated_at = CURRENT_TIMESTAMP",
                       chat_id, user_id, is_typing);

  userver::formats::json::ValueBuilder resp;
  resp["status"] = "ok";
  resp["chat_id"] = chat_id;
  resp["user_id"] = user_id;
  resp["is_typing"] = is_typing;

  response.SetStatus(userver::server::http::HttpStatus::kOk);
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
