#include <create_group_chat_handler.hpp>
#include <utils_handler.hpp>

#include <algorithm>
#include <vector>

#include <userver/formats/json.hpp>
#include <userver/server/http/http_status.hpp>
#include <userver/storages/postgres/component.hpp>
#include <userver/storages/postgres/transaction.hpp>

namespace myservice {

CreateGroupChatHandler::CreateGroupChatHandler(
    const userver::components::ComponentConfig& config,
    const userver::components::ComponentContext& component_context)
    : HttpHandlerBase(config, component_context),
      pg_cluster_(
          component_context
              .FindComponent<userver::components::Postgres>("postgres-db-1")
              .GetCluster()) {}

std::string CreateGroupChatHandler::HandleRequestThrow(
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

  auto name = body["name"].As<std::string>();
  auto creator_id = body["creator_id"].As<int>();
  auto participants = body["participants"];

  if (utils_handler::IsBlank(name)) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("Field 'name' is required");
  }

  if (creator_id <= 0) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson(
        "Field 'creator_id' must be a positive integer");
  }

  std::vector<int> participant_ids;
  for (const auto& p : participants) {
    int user_id = p.As<int>(0);
    if (user_id <= 0) {
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson(
          "Each participant must be a positive integer");
    }
    participant_ids.push_back(user_id);
  }

  if (participant_ids.empty()) {
    response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
    return utils_handler::MakeErrorJson("participants must not be empty");
  }

  if (std::find(participant_ids.begin(), participant_ids.end(), creator_id) ==
      participant_ids.end()) {
    participant_ids.push_back(creator_id);
  }

  std::sort(participant_ids.begin(), participant_ids.end());
  participant_ids.erase(
      std::unique(participant_ids.begin(), participant_ids.end()),
      participant_ids.end());

  auto transaction =
      pg_cluster_->Begin(userver::storages::postgres::ClusterHostType::kMaster,
                         userver::storages::postgres::TransactionOptions{});

  try {
    auto check_result = transaction.Execute(
        "SELECT COUNT(*) FROM seagull_schema.users "
        "WHERE user_id = ANY($1)",
        participant_ids);

    int found = check_result.AsSingleRow<int>();
    if (found != static_cast<int>(participant_ids.size())) {
      transaction.Rollback();
      response.SetStatus(userver::server::http::HttpStatus::kBadRequest);
      return utils_handler::MakeErrorJson("Some users do not exist");
    }

    auto chat_result = transaction.Execute(
        "INSERT INTO seagull_schema.chats (name, type) "
        "VALUES ($1, 0) RETURNING chat_id",
        name);

    int chat_id = chat_result.AsSingleRow<int>();

    for (const int participant_id : participant_ids) {
      transaction.Execute(
          "INSERT INTO seagull_schema.chat_users (chat_id, user_id) "
          "VALUES($1, $2)",
          chat_id, participant_id);
    }

    transaction.Commit();

    userver::formats::json::ValueBuilder resp;
    resp["chat_id"] = chat_id;
    resp["name"] = name;
    resp["creator_id"] = creator_id;
    resp["participants"] = participants;
    resp["chat_type"] = "group";

    response.SetStatus(userver::server::http::HttpStatus::kCreated);
    return userver::formats::json::ToString(resp.ExtractValue());
  } catch (const std::exception& e) {
    transaction.Rollback();
    response.SetStatus(userver::server::http::HttpStatus::kInternalServerError);
    return utils_handler::MakeErrorJson("Failed create chat");
  }
}

}  // namespace myservice
