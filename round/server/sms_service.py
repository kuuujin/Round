import os
from solapi import SolapiMessageService
from solapi.model import RequestMessage

# API 키와 Secret은 코드에 직접 적는 것보다 환경 변수에서 불러오는 것이 안전합니다.
API_KEY = os.environ.get("SOLAPI_API_KEY")
API_SECRET = os.environ.get("SOLAPI_API_SECRET")
SENDER_PHONE = os.environ.get("SENDER_PHONE") # 발신번호도 환경변수로 관리

# Solapi 메시지 서비스 초기화
message_service = SolapiMessageService(api_key=API_KEY, api_secret=API_SECRET)

def send_sms(recipient_number, text_message):
    """
    지정된 번호로 SMS 메시지를 발송하는 함수입니다.

    Args:
        recipient_number (str): 수신자 전화번호 ('-' 제외)
        text_message (str): 발송할 메시지 내용

    Returns:
        bool: 발송 성공 시 True, 실패 시 False
    """
    try:
        message = RequestMessage(
            from_=SENDER_PHONE,
            to=recipient_number,
            text=text_message,
        )
        response = message_service.send(message)
        
        # 성공 여부 확인 (요청은 성공했으나, 실제 발송이 실패할 수도 있음)
        if response.group_info.count.registered_success > 0:
            print(f"메시지 발송 성공! (수신번호: {recipient_number})")
            return True
        else:
            print(f"메시지 발송 실패: {response}")
            return False

    except Exception as e:
        print(f"메시지 발송 중 에러 발생: {str(e)}")
        return False