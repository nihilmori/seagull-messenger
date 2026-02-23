#include <send_message_handler.hpp>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>

namespace myservice {

SendMessageHandler::SendMessageHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string SendMessageHandler::HandleRequestThrow(
    const userver::server::http::HttpRequest& request,
    userver::server::request::RequestContext&) const {
  auto& response = request.GetHttpResponse();
  response.SetContentType("application/json");

  const auto body = userver::formats::json::FromString(request.RequestBody());
  const auto sender_id = body["sender_id"].As<int>(0);
  const auto chat_id = body["chat_id"].As<int>(0);
  const auto content = body["content"].As<std::string>("");

    const auto msg_result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kMaster,
      "INSERT INTO seagull_schema.messages(content) VALUES($1) RETURNING message_id",
      content);
    const auto message_id = msg_result[0]["message_id"].As<int>();
    pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kMaster,
      "INSERT INTO seagull_schema.actions(sender_id, message_id, chat_id) VALUES($1, $2, $3)",
      sender_id, message_id, chat_id);
    userver::formats::json::ValueBuilder resp;
    resp["message_id"] = message_id;
    resp["sender_id"] = sender_id;
    resp["chat_id"] = chat_id;
    resp["content"] = content;
    return userver::formats::json::ToString(resp.ExtractValue());
  resp["sent_at"] = msg_row["sent_at"].As<std::string>();
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
