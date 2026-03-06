#include <send_message_handler.hpp>
#include <utils_handler.hpp>

#include <tuple>
#include <vector>
#include <algorithm>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>
#include <userver/storages/postgres/transaction.hpp>

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
  auto chat_id = body["chat_id"].As<int>(0);
  const auto content = body["content"].As<std::string>("");
  const auto receiver_id = body["receiver_id"].As<int>(0);

  if (sender_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Field 'sender_id' must be a positive integer");
  }

  if (utils_handler::IsBlank(content)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'content' must not be empty");
  }

  bool is_private_chat = (chat_id == 0);
  
  if (is_private_chat) {
    if (receiver_id <= 0) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson(
          "For private chat, 'receiver_id' must be a positive integer");
    }
    if (sender_id == receiver_id) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson("Cannot send message to yourself");
    }
  } else if (chat_id < 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'chat_id' must be >= 0");
  }

  const auto sender_result = pg_cluster_->Execute(
      userver::storages::postgres::ClusterHostType::kSlave,
      "SELECT user_id FROM seagull_schema.users WHERE user_id = $1", sender_id);

  if (sender_result.IsEmpty()) {
    response.SetStatus(userver::server::http::HttpStatus::kNotFound);
    return utils_handler::MakeErrorJson("Sender user not found");
  }

  if (is_private_chat) {
    const auto receiver_result = pg_cluster_->Execute(
        userver::storages::postgres::ClusterHostType::kSlave,
        "SELECT user_id FROM seagull_schema.users WHERE user_id = $1", receiver_id);

    if (receiver_result.IsEmpty()) {
      response.SetStatus(userver::server::http::HttpStatus::kNotFound);
      return utils_handler::MakeErrorJson("Receiver user not found");
    }
  }

  auto transaction =
      pg_cluster_->Begin(userver::storages::postgres::ClusterHostType::kMaster);

  try {
    if (is_private_chat) {
      auto chat_result = transaction.Execute(
          "SELECT c.chat_id "
          "FROM seagull_schema.chats c "
          "WHERE c.type = 1 AND c.chat_id IN ("
          "  SELECT chat_id FROM seagull_schema.chat_users "
          "  WHERE user_id = $1"
          ") AND c.chat_id IN ("
          "  SELECT chat_id FROM seagull_schema.chat_users "
          "  WHERE user_id = $2"
          ")",
          sender_id, receiver_id);

      if (chat_result.IsEmpty()) {
        std::string chat_name = "private_" + std::to_string(sender_id) + 
                                "_" + std::to_string(receiver_id);
        
        auto new_chat = transaction.Execute(
            "INSERT INTO seagull_schema.chats (name, type) "
            "VALUES ($1, 1) RETURNING chat_id",
            chat_name);

        chat_id = new_chat.AsSingleRow<int>();

        std::vector<int> user_ids = {sender_id, receiver_id};
        transaction.Execute(
            "INSERT INTO seagull_schema.chat_users (chat_id, user_id) "
            "SELECT $1, user_id FROM UNNEST($2::int[]) AS user_id",
            chat_id, user_ids);
      } else {
        chat_id = chat_result.AsSingleRow<int>();
      }
    } else {
      auto participant_check = transaction.Execute(
          "SELECT user_id FROM seagull_schema.chat_users "
          "WHERE chat_id = $1 AND user_id = $2",
          chat_id, sender_id);

      if (participant_check.IsEmpty()) {
        transaction.Rollback();
        response.SetStatus(userver::server::http::HttpStatus::kForbidden);
        return utils_handler::MakeErrorJson("Sender is not a participant of this chat");
      }
    }

    const auto msg_result = transaction.Execute(
        "INSERT INTO seagull_schema.messages(content) VALUES($1) "
        "RETURNING message_id, content, to_char(sent_at AT TIME ZONE "
        "'Europe/Moscow', 'DD.MM.YYYY HH24:MI:SS') AS sent_at",
        content);

    const auto [message_id, stored_content, sent_at] =
        msg_result.AsSingleRow<std::tuple<int, std::string, std::string>>();

    transaction.Execute(
        "INSERT INTO seagull_schema.actions(sender_id, message_id, chat_id) "
        "VALUES($1, $2, $3)",
        sender_id, message_id, chat_id);

    transaction.Commit();

    userver::formats::json::ValueBuilder resp;
    resp["message_id"] = message_id;
    resp["sender_id"] = sender_id;
    resp["chat_id"] = chat_id;
    resp["content"] = stored_content;
    resp["sent_at"] = sent_at;

    if (is_private_chat) {
      resp["receiver_id"] = receiver_id;
      resp["is_new_chat"] = (chat_id != body["chat_id"].As<int>(0));
    }

    response.SetStatus(userver::server::http::HttpStatus::kCreated);
    return userver::formats::json::ToString(resp.ExtractValue());

  } catch (const std::exception& e) {
    transaction.Rollback();
    return utils_handler::MakeErrorJson("Failed to send message");
  }
}

}  // namespace myservice
