#include <send_message_handler.hpp>

#include <utils_handler.hpp>

#include <tuple>

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

  userver::formats::json::Value body;
  try {
    body = userver::formats::json::FromString(request.RequestBody());
  } catch (const std::exception&) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Invalid JSON body");
  }

  const auto sender_id = body["sender_id"].As<int>(0);
  const auto chat_id = body["chat_id"].As<int>(0);
  const auto content = body["content"].As<std::string>("");

  if (sender_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Field 'sender_id' must be a positive integer");
  }

  if (chat_id < 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'chat_id' must be >= 0");
  }

  if (utils_handler::IsBlank(content)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'content' must not be empty");
  }

  const auto sender_result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kSlave,
      "SELECT user_id FROM seagull_schema.users WHERE user_id = $1", sender_id);

  if (sender_result.IsEmpty()) {
    response.SetStatus(userver::server::http::HttpStatus::kNotFound);
    return utils_handler::MakeErrorJson("Sender user not found");
  }

  const auto msg_result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kMaster,
      "INSERT INTO seagull_schema.messages(content) VALUES($1) "
      "RETURNING message_id, content, to_char(sent_at AT TIME ZONE "
      "'Europe/Moscow', 'DD.MM.YYYY HH24:MI:SS')",
      content);

  const auto [message_id, stored_content, sent_at] =
      msg_result.AsSingleRow<std::tuple<int, std::string, std::string>>();

  pg_cluster_->Execute(userver::storages::postgres::ClusterHostType::kMaster,
                       "INSERT INTO seagull_schema.actions(sender_id, "
                       "message_id, chat_id) VALUES($1, $2, $3)",
                       sender_id, message_id, chat_id);

  userver::formats::json::ValueBuilder resp;
  resp["message_id"] = message_id;
  resp["sender_id"] = sender_id;
  resp["chat_id"] = chat_id;
  resp["content"] = stored_content;
  resp["sent_at"] = sent_at;

  response.SetStatus(userver::server::http::HttpStatus::kCreated);
  return userver::formats::json::ToString(resp.ExtractValue());
}

}  // namespace myservice
