#include <get_messages_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

GetMessagesHandler::GetMessagesHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string GetMessagesHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto& chat_id_str = request.GetArg("chat_id");
  if (chat_id_str.empty()) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    userver::formats::json::ValueBuilder result;
    result["error"] = "chat_id is required";
    return userver::formats::json::ToString(result.ExtractValue());
  }

  const auto chat_id = std::stoi(chat_id_str);

  // Базовое получение сообщений
  const auto result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kSlave,
      "SELECT m.message_id, m.content, a.sender_id, a.chat_id FROM seagull_schema.actions a JOIN seagull_schema.messages m ON a.message_id = m.message_id WHERE a.chat_id = $1 ORDER BY m.message_id ASC",
      chat_id);
  userver::formats::json::ValueBuilder messages(userver::formats::common::Type::kArray);
  for (const auto& row : result) {
    userver::formats::json::ValueBuilder msg;
    msg["message_id"] = row["message_id"].As<int>();
    msg["content"] = row["content"].As<std::string>();
    msg["sender_id"] = row["sender_id"].As<int>();
    msg["chat_id"] = row["chat_id"].As<int>();
    messages.PushBack(std::move(msg));
  }
  return userver::formats::json::ToString(messages.ExtractValue());

  userver::formats::json::ValueBuilder resp;
  resp["messages"] = std::move(messages);
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
