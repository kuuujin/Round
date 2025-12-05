from firebase_admin import messaging

def send_fcm_notification(token, title, body, data=None):
    if not token: 
        return
    
    try:
        # 데이터가 있으면 포함해서 메시지 생성
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data,  # 👈 핵심: 데이터를 여기에 넣어줘야 합니다
            token=token,
        )
        
        response = messaging.send(message)
        print('Successfully sent message:', response)
        return response
    except Exception as e:
        print('Error sending message:', e)
        return None