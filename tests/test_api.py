async def _register_user(service_client, login, password='TestPass123', name='User'):
    response = await service_client.post(
        '/api/register',
        json={
            'login': login,
            'password': password,
            'name': name,
            'bio': 'bio',
        },
    )
    return response


async def _create_group_chat(service_client, creator_id, name='Test Chat'):
    response = await service_client.post(
        '/api/chats/group',
        json={
            'name': name,
            'creator_id': creator_id,
            'participants': [creator_id],
        },
    )
    return response


# Проверяем успешную регистрацию нового пользователя.
async def test_register_success(service_client, pgsql):
    response = await _register_user(service_client, 'testuser', 'TestPass123', 'Test User')
    assert response.status_code == 201
    payload = response.json()
    assert payload['user_id'] > 0
    assert payload['login'] == 'testuser'


# Проверяем, что повторный логин при регистрации запрещен.
async def test_register_duplicate_login(service_client, pgsql):
    await _register_user(service_client, 'dup_login')
    response = await _register_user(service_client, 'dup_login', 'AnotherPass123')
    assert response.status_code == 409


# Проверяем успешный вход с корректными данными.
async def test_login_success(service_client, pgsql):
    await _register_user(service_client, 'login_ok', 'SecurePass123')
    response = await service_client.post(
        '/api/login',
        json={'login': 'login_ok', 'password': 'SecurePass123'},
    )
    assert response.status_code == 200
    assert response.json()['login'] == 'login_ok'


# Проверяем отказ во входе при неверном пароле.
async def test_login_wrong_password(service_client, pgsql):
    await _register_user(service_client, 'login_fail', 'RightPass123')
    response = await service_client.post(
        '/api/login',
        json={'login': 'login_fail', 'password': 'WrongPass123'},
    )
    assert response.status_code == 401


# Проверяем создание группового чата.
async def test_create_group_chat(service_client, pgsql):
    user_id = (await _register_user(service_client, 'chat_creator')).json()['user_id']
    response = await _create_group_chat(service_client, user_id, 'My Group')
    assert response.status_code == 201
    assert response.json()['chat_id'] > 0


# Проверяем получение списка чатов пользователя.
async def test_get_chats(service_client, pgsql):
    user_id = (await _register_user(service_client, 'chat_lister')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, user_id, 'Listed Chat')).json()['chat_id']
    await service_client.post(
        '/api/messages/send',
        json={'sender_id': user_id, 'chat_id': chat_id, 'content': 'hello'},
    )
    response = await service_client.get(f'/api/chats?user_id={user_id}')
    assert response.status_code == 200
    assert len(response.json()['chats']) >= 1


# Проверяем изменение названия чата.
async def test_update_chat_name(service_client, pgsql):
    user_id = (await _register_user(service_client, 'chat_renamer')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, user_id, 'Old Name')).json()['chat_id']

    response = await service_client.patch(
        f'/api/chat/{chat_id}',
        json={'user_id': user_id, 'name': 'New Name'},
    )
    assert response.status_code == 200
    assert response.json()['name'] == 'New Name'


# Проверяем получение профиля пользователя.
async def test_get_user_profile(service_client, pgsql):
    user_id = (await _register_user(service_client, 'profile_user', name='Profile User')).json()['user_id']
    response = await service_client.get(f'/api/user/profile?user_id={user_id}')
    assert response.status_code == 200
    payload = response.json()
    assert payload['user_id'] == user_id
    assert payload['login'] == 'profile_user'


# Проверяем обновление имени и био пользователя.
async def test_update_user_profile(service_client, pgsql):
    user_id = (await _register_user(service_client, 'profile_upd')).json()['user_id']
    response = await service_client.patch(
        '/api/user/profile',
        json={'user_id': user_id, 'name': 'New Name', 'bio': 'New bio'},
    )
    assert response.status_code == 200
    assert response.json()['name'] == 'New Name'


# Проверяем смену пароля и повторную авторизацию.
async def test_update_user_password(service_client, pgsql):
    user_id = (await _register_user(service_client, 'pwd_upd', 'OldPassword123')).json()['user_id']

    update_resp = await service_client.patch(
        '/api/user/profile',
        json={
            'user_id': user_id,
            'current_password': 'OldPassword123',
            'new_password': 'NewPassword456',
        },
    )
    assert update_resp.status_code == 200

    old_login = await service_client.post(
        '/api/login',
        json={'login': 'pwd_upd', 'password': 'OldPassword123'},
    )
    assert old_login.status_code == 401

    new_login = await service_client.post(
        '/api/login',
        json={'login': 'pwd_upd', 'password': 'NewPassword456'},
    )
    assert new_login.status_code == 200


# Проверяем отправку сообщения и его чтение из чата.
async def test_send_and_get_messages(service_client, pgsql):
    sender_id = (await _register_user(service_client, 'sender_user')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, sender_id, 'Message Chat')).json()['chat_id']

    send_resp = await service_client.post(
        '/api/messages/send',
        json={'sender_id': sender_id, 'chat_id': chat_id, 'content': 'Hello!'},
    )
    assert send_resp.status_code == 201

    get_resp = await service_client.get(f'/api/messages?chat_id={chat_id}&user_id={sender_id}')
    assert get_resp.status_code == 200
    assert len(get_resp.json()['messages']) >= 1


# Проверяем редактирование сообщения его автором.
async def test_edit_message(service_client, pgsql):
    user_id = (await _register_user(service_client, 'msg_editor')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, user_id, 'Edit Chat')).json()['chat_id']

    msg_resp = await service_client.post(
        '/api/messages/send',
        json={'sender_id': user_id, 'chat_id': chat_id, 'content': 'Original'},
    )
    message_id = msg_resp.json()['message_id']

    edit_resp = await service_client.patch(
        f'/api/messages/{message_id}',
        json={'user_id': user_id, 'content': 'Edited'},
    )
    assert edit_resp.status_code == 200
    assert edit_resp.json()['content'] == 'Edited'


# Проверяем запрет редактирования чужого сообщения.
async def test_edit_message_forbidden_for_non_sender(service_client, pgsql):
    user1_id = (await _register_user(service_client, 'msg_sender')).json()['user_id']
    user2_id = (await _register_user(service_client, 'msg_other')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, user1_id, 'Shared Chat')).json()['chat_id']

    add_resp = await service_client.post(
        f'/api/chat/{chat_id}/users/add',
        json={'requester_id': user1_id, 'user_id': user2_id},
    )
    assert add_resp.status_code == 200

    msg_resp = await service_client.post(
        '/api/messages/send',
        json={'sender_id': user1_id, 'chat_id': chat_id, 'content': 'Owner text'},
    )
    message_id = msg_resp.json()['message_id']

    edit_resp = await service_client.patch(
        f'/api/messages/{message_id}',
        json={'user_id': user2_id, 'content': 'Hijack'},
    )
    assert edit_resp.status_code == 403


# Проверяем поиск пользователей по имени.
async def test_search_users_by_name(service_client, pgsql):
    await _register_user(service_client, 'alice_login', name='Alice Wonder')
    response = await service_client.get('/api/users/search?query=Alice')
    assert response.status_code == 200
    assert response.json()['count'] >= 1


# Проверяем добавление пользователя в групповой чат.
async def test_add_user_to_chat(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'chat_owner')).json()['user_id']
    guest_id = (await _register_user(service_client, 'chat_guest')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Add Chat')).json()['chat_id']

    response = await service_client.post(
        f'/api/chat/{chat_id}/users/add',
        json={'requester_id': owner_id, 'user_id': guest_id},
    )
    assert response.status_code == 200


# Проверяем удаление пользователя из группового чата.
async def test_remove_user_from_chat(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'chat_remove_owner')).json()['user_id']
    guest_id = (await _register_user(service_client, 'chat_remove_guest')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Remove Chat')).json()['chat_id']

    await service_client.post(
        f'/api/chat/{chat_id}/users/add',
        json={'requester_id': owner_id, 'user_id': guest_id},
    )

    response = await service_client.post(
        f'/api/chat/{chat_id}/users/remove',
        json={'requester_id': owner_id, 'user_id': guest_id},
    )
    assert response.status_code == 200


# Проверяем выход пользователя из чата.
async def test_leave_chat(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'leave_owner')).json()['user_id']
    guest_id = (await _register_user(service_client, 'leave_guest')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Leave Chat')).json()['chat_id']

    await service_client.post(
        f'/api/chat/{chat_id}/users/add',
        json={'requester_id': owner_id, 'user_id': guest_id},
    )

    response = await service_client.post(
        f'/api/chat/{chat_id}/leave',
        json={'user_id': guest_id},
    )
    assert response.status_code == 200


# Проверяем получение информации о чате.
async def test_get_chat_info(service_client, pgsql):
    user_id = (await _register_user(service_client, 'chat_info_user')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, user_id, 'Info Chat')).json()['chat_id']

    response = await service_client.get(f'/api/chat/{chat_id}?user_id={user_id}')
    assert response.status_code == 200
    assert response.json()['chat_id'] == chat_id
    assert response.json()['type_name'] == 'group'


# Проверяем отправку сообщения в личный чат.
async def test_send_private_message(service_client, pgsql):
    sender_id = (await _register_user(service_client, 'pm_sender')).json()['user_id']
    receiver_id = (await _register_user(service_client, 'pm_receiver')).json()['user_id']

    response = await service_client.post(
        '/api/messages/send',
        json={
            'sender_id': sender_id,
            'receiver_id': receiver_id,
            'chat_id': 0,
            'content': 'Private hello',
        },
    )
    assert response.status_code == 201
    assert response.json()['chat_id'] > 0


# Проверяем запрет чтения сообщений для неучастника чата.
async def test_get_messages_forbidden_for_non_participant(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'msgs_owner')).json()['user_id']
    other_id = (await _register_user(service_client, 'msgs_other')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Forbidden Chat')).json()['chat_id']

    await service_client.post(
        '/api/messages/send',
        json={'sender_id': owner_id, 'chat_id': chat_id, 'content': 'Secret'},
    )

    response = await service_client.get(
        f'/api/messages?chat_id={chat_id}&user_id={other_id}'
    )
    assert response.status_code == 403


# Проверяем поиск сообщений в одном чате.
async def test_search_messages_in_chat(service_client, pgsql):
    user_id = (await _register_user(service_client, 'search_chat_user')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, user_id, 'Search Chat')).json()['chat_id']

    await service_client.post(
        '/api/messages/send',
        json={'sender_id': user_id, 'chat_id': chat_id, 'content': 'Needle one'},
    )
    await service_client.post(
        '/api/messages/send',
        json={'sender_id': user_id, 'chat_id': chat_id, 'content': 'Other text'},
    )

    response = await service_client.get(
        f'/api/messages/search?query=Needle&user_id={user_id}&chat_id={chat_id}'
    )
    assert response.status_code == 200
    assert response.json()['count'] >= 1


# Проверяем поиск сообщений по всем чатам пользователя.
async def test_search_messages_all_chats(service_client, pgsql):
    user_id = (await _register_user(service_client, 'search_all_user')).json()['user_id']
    chat1_id = (await _create_group_chat(service_client, user_id, 'Search All 1')).json()['chat_id']
    chat2_id = (await _create_group_chat(service_client, user_id, 'Search All 2')).json()['chat_id']

    await service_client.post(
        '/api/messages/send',
        json={'sender_id': user_id, 'chat_id': chat1_id, 'content': 'FindKey 1'},
    )
    await service_client.post(
        '/api/messages/send',
        json={'sender_id': user_id, 'chat_id': chat2_id, 'content': 'FindKey 2'},
    )

    response = await service_client.get(
        f'/api/messages/search?query=FindKey&user_id={user_id}'
    )
    assert response.status_code == 200
    assert response.json()['count'] >= 2


# Проверяем удаление сообщения автором.
async def test_delete_message(service_client, pgsql):
    user_id = (await _register_user(service_client, 'delete_msg_owner')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, user_id, 'Delete Chat')).json()['chat_id']

    msg_resp = await service_client.post(
        '/api/messages/send',
        json={'sender_id': user_id, 'chat_id': chat_id, 'content': 'To delete'},
    )
    message_id = msg_resp.json()['message_id']

    response = await service_client.delete(
        f'/api/messages/{message_id}',
        json={'user_id': user_id},
    )
    assert response.status_code == 200
    assert response.json()['deleted'] is True


# Проверяем запрет удаления чужого сообщения.
async def test_delete_message_forbidden_for_non_sender(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'delete_owner')).json()['user_id']
    other_id = (await _register_user(service_client, 'delete_other')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Delete Forbidden')).json()['chat_id']

    await service_client.post(
        f'/api/chat/{chat_id}/users/add',
        json={'requester_id': owner_id, 'user_id': other_id},
    )

    msg_resp = await service_client.post(
        '/api/messages/send',
        json={'sender_id': owner_id, 'chat_id': chat_id, 'content': 'Keep'},
    )
    message_id = msg_resp.json()['message_id']

    response = await service_client.delete(
        f'/api/messages/{message_id}',
        json={'user_id': other_id},
    )
    assert response.status_code == 403


# --- Дополнительные тесты ---


# Регистрация: пароль не соответствует требованиям -> 400.
async def test_register_invalid_password(service_client, pgsql):
    response = await _register_user(service_client, 'weak_pwd_user', password='short')
    assert response.status_code == 400


# Регистрация: имя короче 2 символов -> 400.
async def test_register_short_name(service_client, pgsql):
    response = await _register_user(service_client, 'short_name_user', name='X')
    assert response.status_code == 400


# Логин: несуществующий пользователь -> 401.
async def test_login_unknown_user(service_client, pgsql):
    response = await service_client.post(
        '/api/login',
        json={'login': 'nobody_here', 'password': 'AnyPass123'},
    )
    assert response.status_code == 401


# Профиль: несуществующий user_id -> 404.
async def test_get_user_profile_not_found(service_client, pgsql):
    response = await service_client.get('/api/user/profile?user_id=999999')
    assert response.status_code == 404


# Профиль: попытка занять уже существующий логин -> 409.
async def test_update_user_profile_login_taken(service_client, pgsql):
    await _register_user(service_client, 'taken_login')
    user_id = (await _register_user(service_client, 'login_changer')).json()['user_id']
    response = await service_client.patch(
        '/api/user/profile',
        json={'user_id': user_id, 'login': 'taken_login'},
    )
    assert response.status_code == 409


# Поиск пользователей: запрос короче 2 символов -> 400.
async def test_search_users_short_query(service_client, pgsql):
    response = await service_client.get('/api/users/search?query=a')
    assert response.status_code == 400


# Информация о чате: пользователь не участник -> 403.
async def test_get_chat_info_not_participant(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'info_owner')).json()['user_id']
    other_id = (await _register_user(service_client, 'info_other')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Private Group')).json()['chat_id']

    response = await service_client.get(f'/api/chat/{chat_id}?user_id={other_id}')
    assert response.status_code == 403


# Добавление в чат: пользователь уже в чате -> 409.
async def test_add_user_already_in_chat(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'dup_add_owner')).json()['user_id']
    guest_id = (await _register_user(service_client, 'dup_add_guest')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Dup Add')).json()['chat_id']

    await service_client.post(
        f'/api/chat/{chat_id}/users/add',
        json={'requester_id': owner_id, 'user_id': guest_id},
    )
    response = await service_client.post(
        f'/api/chat/{chat_id}/users/add',
        json={'requester_id': owner_id, 'user_id': guest_id},
    )
    assert response.status_code == 409


# Удаление участника: нельзя удалить самого себя -> 400.
async def test_remove_self_from_chat(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'self_remove')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Self Remove')).json()['chat_id']

    response = await service_client.post(
        f'/api/chat/{chat_id}/users/remove',
        json={'requester_id': owner_id, 'user_id': owner_id},
    )
    assert response.status_code == 400


# Выход из чата: запрещён в приватном чате -> 400.
async def test_leave_private_chat_forbidden(service_client, pgsql):
    sender_id = (await _register_user(service_client, 'leave_priv_a')).json()['user_id']
    receiver_id = (await _register_user(service_client, 'leave_priv_b')).json()['user_id']

    send_resp = await service_client.post(
        '/api/messages/send',
        json={
            'sender_id': sender_id,
            'receiver_id': receiver_id,
            'chat_id': 0,
            'content': 'hi',
        },
    )
    chat_id = send_resp.json()['chat_id']

    response = await service_client.post(
        f'/api/chat/{chat_id}/leave',
        json={'user_id': sender_id},
    )
    assert response.status_code == 400


# Отправка сообщения: пустой content -> 400.
async def test_send_message_blank_content(service_client, pgsql):
    user_id = (await _register_user(service_client, 'blank_sender')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, user_id, 'Blank Chat')).json()['chat_id']

    response = await service_client.post(
        '/api/messages/send',
        json={'sender_id': user_id, 'chat_id': chat_id, 'content': ''},
    )
    assert response.status_code == 400


# Отправка сообщения: отправитель не участник чата -> 403.
async def test_send_message_not_participant(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'snd_owner')).json()['user_id']
    other_id = (await _register_user(service_client, 'snd_other')).json()['user_id']
    chat_id = (await _create_group_chat(service_client, owner_id, 'Closed Chat')).json()['chat_id']

    response = await service_client.post(
        '/api/messages/send',
        json={'sender_id': other_id, 'chat_id': chat_id, 'content': 'sneak'},
    )
    assert response.status_code == 403


# Непрочитанные сообщения: после отправки чужого сообщения unread > 0.
async def test_get_unread_messages(service_client, pgsql):
    a_id = (await _register_user(service_client, 'unread_a')).json()['user_id']
    b_id = (await _register_user(service_client, 'unread_b')).json()['user_id']

    await service_client.post(
        '/api/messages/send',
        json={'sender_id': a_id, 'receiver_id': b_id, 'chat_id': 0, 'content': 'ping'},
    )

    response = await service_client.get(f'/api/messages/unread?user_id={b_id}')
    assert response.status_code == 200
    assert response.json()['total_unread'] >= 1


# Отметка прочитанным: после mark unread обнуляется.
async def test_mark_messages_read(service_client, pgsql):
    a_id = (await _register_user(service_client, 'read_a')).json()['user_id']
    b_id = (await _register_user(service_client, 'read_b')).json()['user_id']

    send_resp = await service_client.post(
        '/api/messages/send',
        json={'sender_id': a_id, 'receiver_id': b_id, 'chat_id': 0, 'content': 'mark me'},
    )
    chat_id = send_resp.json()['chat_id']

    mark_resp = await service_client.post(
        '/api/messages/read',
        json={'user_id': b_id, 'chat_id': chat_id},
    )
    assert mark_resp.status_code == 200

    unread = await service_client.get(f'/api/messages/unread?user_id={b_id}')
    assert unread.json()['total_unread'] == 0


# Статус печати: после set is_typing=true собеседник видит запись.
async def test_set_and_get_typing(service_client, pgsql):
    a_id = (await _register_user(service_client, 'type_a')).json()['user_id']
    b_id = (await _register_user(service_client, 'type_b')).json()['user_id']

    send_resp = await service_client.post(
        '/api/messages/send',
        json={'sender_id': a_id, 'receiver_id': b_id, 'chat_id': 0, 'content': 'open chat'},
    )
    chat_id = send_resp.json()['chat_id']

    set_resp = await service_client.post(
        f'/api/chat/{chat_id}/typing',
        json={'chat_id': chat_id, 'user_id': a_id, 'is_typing': True},
    )
    assert set_resp.status_code == 200

    get_resp = await service_client.get(
        f'/api/chat/{chat_id}/typing?chat_id={chat_id}&user_id={b_id}',
    )
    assert get_resp.status_code == 200
    typing = get_resp.json()
    assert typing['count'] >= 1
    assert any(u['user_id'] == a_id for u in typing['typing_users'])


# Стена: создание поста -> 201.
async def test_wall_create_post(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'wall_owner')).json()['user_id']
    author_id = (await _register_user(service_client, 'wall_author')).json()['user_id']

    response = await service_client.post(
        f'/api/wall/{owner_id}/post',
        json={'author_id': author_id, 'content': 'Привет на стене'},
    )
    assert response.status_code == 201
    assert response.json()['post_id'] > 0


# Стена: получение постов после публикации.
async def test_wall_get_posts(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'wall_get_owner')).json()['user_id']
    author_id = (await _register_user(service_client, 'wall_get_author')).json()['user_id']

    await service_client.post(
        f'/api/wall/{owner_id}/post',
        json={'author_id': author_id, 'content': 'first post'},
    )

    response = await service_client.get(f'/api/wall/{owner_id}/posts')
    assert response.status_code == 200
    assert response.json()['count'] >= 1


# Стена: автор удаляет свой пост -> 200.
async def test_wall_delete_own_post(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'wall_del_owner')).json()['user_id']
    author_id = (await _register_user(service_client, 'wall_del_author')).json()['user_id']

    create_resp = await service_client.post(
        f'/api/wall/{owner_id}/post',
        json={'author_id': author_id, 'content': 'to delete'},
    )
    post_id = create_resp.json()['post_id']

    delete_resp = await service_client.delete(
        f'/api/wall/post/{post_id}?user_id={author_id}',
    )
    assert delete_resp.status_code == 200
    assert delete_resp.json()['deleted'] is True


# Стена: посторонний пользователь не может удалить пост -> 403.
async def test_wall_delete_post_forbidden(service_client, pgsql):
    owner_id = (await _register_user(service_client, 'wall_fb_owner')).json()['user_id']
    author_id = (await _register_user(service_client, 'wall_fb_author')).json()['user_id']
    stranger_id = (await _register_user(service_client, 'wall_fb_other')).json()['user_id']

    create_resp = await service_client.post(
        f'/api/wall/{owner_id}/post',
        json={'author_id': author_id, 'content': 'keep me'},
    )
    post_id = create_resp.json()['post_id']

    delete_resp = await service_client.delete(
        f'/api/wall/post/{post_id}?user_id={stranger_id}',
    )
    assert delete_resp.status_code == 403
