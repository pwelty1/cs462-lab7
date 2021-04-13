ruleset wovyn_base {
    meta {
        use module com.twilio alias twilio
        with
          account_sid = meta:rulesetConfig{"account_sid"}
          authtoken = meta:rulesetConfig{"authtoken"}
        use module store.temperature alias temperature
       shares lastResponse, lastTemp, lastMessage, temperatures, threshold_violations, inrange_temperatures, get_config
    }
    global {
      lastResponse = function() {
        {}.put(ent:lastTimestamp,ent:lastResponse)
      }
      lastTemp = function() {
        {}.put(ent:high_temp)
      }
      lastMessage = function() {
        {}.put(ent:lastMessage)
      }

      temperatures = function() {
        temperature:temperatures()
      }
      threshold_violations  = function() {
        temperature:threshold_violations()
      }
      inrange_temperatures = function() {
        temperature:inrange_temperatures()  
      }      

      get_config = function () {
        {
          "recipient_phone_number": ent:recipient_phone_number,
          "temperature_threshold": ent:temperature_threshold,
        }
      }
    }

    rule update_configuration {
      select when wovyn config
      pre {
        recipient_phone_number = event:attrs{"recipient_phone_number"}.klog("New recipient number")
        temperature_threshold = event:attrs{"temperature_threshold"}.klog("New temperature threshold")
      }
      always {
        ent:recipient_phone_number := recipient_phone_number
        ent:temperature_threshold := temperature_threshold
      }
    }
  
    rule process_tempature {
      select when wovyn heartbeat
      if event:attrs >< "genericThing" then
        send_directive(event:attrs.klog("attrs"))
        fired {
          ent:lastResponse := event:attrs
          ent:lastTimestamp := time:now()
          raise wovyn event "new_temperature_reading" 
            attributes 
            { "temperature": event:attrs{"genericThing"}{"data"}{"temperature"}[0], "Timestamp": time:now()}
        }
    }

    rule find_high_temps {
      select when wovyn new_temperature_reading
      send_directive(event:attrs.klog("attrs"))
      fired{
        ent:high_temp := event:attrs{"temperature"}
        raise wovyn event "threshold_violation" 
            attributes event:attrs 
            if event:attrs{"temperature"}{"temperatureF"} > ent:temperature_threshold
      }
    }

    rule threshold_notification {
      select when wovyn threshold_violation
      pre{
        temperature = event:attrs{"temperature"}{"temperatureF"}.klog("Firing notification with temperature")
        timestamp = event:attrs{"timestamp"}.klog("Timing")
      }
      // twilio:sendMessage(<<#{ent:recipient_phone_number}>>,messageContent) setting(response)
      always {
        raise sensor event "notify_high_temperature"
          attributes {"message":<<Temperature #{temperature}F was too high. Reading happened at #{timestamp}>>}
          if temperature && timestamp
      }
      // fired {
      //   ent:lastMessage := response
      //   // raise sms event "sent" attributes event:attrs
      // }
    }
  } 