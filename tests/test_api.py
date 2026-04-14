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
