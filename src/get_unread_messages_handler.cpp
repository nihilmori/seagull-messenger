#include "get_unread_messages_handler.hpp"
#include "utils_handler.hpp"

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

GetUnreadMessagesHandler::GetUnreadMessagesHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string GetUnreadMessagesHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& user_id_str = request.GetArg("user_id");
  int user_id = 0;
  if (!utils_handler::TryParseInt(user_id_str, user_id) || user_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("user_id must be a positive integer");
  }

  const auto user_check = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kSlave,
      "SELECT 1 FROM seagull_schema.users WHERE user_id = $1",
      user_id);

  if (user_check.IsEmpty()) {
    response.SetStatus(userver::server::http::HttpStatus::kNotFound);
    return utils_handler::MakeErrorJson("User not found");
  }

  const auto result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kSlave,
      "WITH user_chats AS ("
      "  SELECT cu.chat_id, cu.last_read_message_id, c.name, c.type "
      "  FROM seagull_schema.chat_users cu "
      "  JOIN seagull_schema.chats c ON cu.chat_id = c.chat_id "
      "  WHERE cu.user_id = $1"
      ")"
      "SELECT "
      "  uc.chat_id, "
      "  uc.name, "
      "  CASE WHEN uc.type = 0 THEN 'group' ELSE 'private' END AS type_name, "
      "  COUNT(m.message_id) AS unread_count "
      "FROM user_chats uc "
      "JOIN seagull_schema.actions a ON uc.chat_id = a.chat_id "
      "JOIN seagull_schema.messages m ON a.message_id = m.message_id "
      "WHERE m.message_id > COALESCE(uc.last_read_message_id, 0) "
      "GROUP BY uc.chat_id, uc.name, uc.type",
      user_id);

  userver::formats::json::ValueBuilder unread_chats(
      userver::formats::common::Type::kArray);
  
  int total_unread = 0;
  
  for (const auto& row : result) {
    userver::formats::json::ValueBuilder chat;
    chat["chat_id"] = row["chat_id"].As<int>();
    chat["chat_name"] = row["name"].As<std::string>();
    chat["type_name"] = row["type_name"].As<std::string>();
    chat["unread_count"] = row["unread_count"].As<int>();
    
    total_unread += row["unread_count"].As<int>();
    
    unread_chats.PushBack(std::move(chat));
  }

  userver::formats::json::ValueBuilder resp;
  resp["user_id"] = user_id;
  resp["total_unread"] = total_unread;
  resp["chats"] = std::move(unread_chats);

  response.SetStatus(userver::server::http::HttpStatus::kOk);
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
