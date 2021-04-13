ruleset com.twilio {
    meta {
      name "twilio"
      description <<
        Testing the Twilio api
        >>

      configure using
      account_sid = ""
      authtoken = ""
      provides messages, sendMessage
    }
    global {
        base_url = "https://api.twilio.com/2010-04-01/"

        sendMessage = defaction(receiver_phone_num,message) {
          authen = {"username":account_sid, "password":authtoken}
          formy = {"From":"+13476964317", "To":receiver_phone_num, "Body":message}
          http:post(<<#{base_url}/Accounts/#{account_sid}/Messages.json>>, auth=authen, form=formy) setting(response)
          return response
        }
        
        messages = function(){
            authen = {"username":account_sid, "password":authtoken}
            resp = http:get(<<#{base_url}/Accounts/#{account_sid}/Messages.json>>, auth=authen)
            resp{"content"}.decode()
          }

      }
  }