ruleset sensor_profile {
    meta {
      use module io.picolabs.wrangler alias wrangler
      use module io.picolabs.subscription alias subs 

      shares get_profile
      provides get_profile
    }
  
    global {
      tags = ["sensor"]
      eventPolicy = {
          "allow": [{"domain": "sensor", "name": "*"}],
          "deny": []
        }
       queryPolicy = {
          "allow": [{"rid": meta:rid, "name": "*"}],
          "deny": []
        }
      get_profile = function () {
        {
          "name": ent:name,
          "location": ent:location,
          "temperature_threshold": ent:temperature_threshold,
          "recipient_phone_number": ent:recipient_phone_number
        }
      }
    }
  
    rule init {
      select when wrangler ruleset_installed where event:attrs{"rids"} >< ctx:rid

      pre {
        name = event:attrs{"name"}
        eci = wrangler:myself(){"eci"}
        parent_eci = wrangler:parent_eci()
        wellKnown_eci = subs:wellKnown_Rx(){"id"}
      }
  
      event:send(
        {
          "eci": parent_eci,
          "domain": "sensor",
          "type": "identify_child",
          "attrs": 
            {
              "name": name,
              "eci": eci,
              "wellKnown_eci": wellKnown_eci
            }
        }
      )
      always {
        ent:name := ""
        ent:location := ""
        ent:temperature_threshold := null
        ent:recipient_phone_number := ""
        ent:manager_eci := ""

        raise sensor event "create_subscription_channel"
          attributes event:attrs
      }
    }

    rule prepare_for_subscription {
        select when sensor create_subscription_channel
    
        if ent:sensor_eci.isnull() then
          wrangler:createChannel(tags, eventPolicy, queryPolicy) setting(channel)
        
        fired {
          ent:name := event:attrs{"name"}.klog("Entity Name: ")
          ent:wellKnown_Rx := wrangler:parent_eci().klog("Entity WellKnown_Rx: ")
          ent:sensor_eci := channel{"id"}.klog("Entity sensor_eci: ")
    
          raise sensor event "new_subscription_request"
        }
      }
    
    rule make_subscription {
        select when sensor new_subscription_request
        
        event:send(
          {
            "eci": ent:wellKnown_Rx,
            "domain": "wrangler",
            "name": "subscription",
            "attrs": {
              "wellKnown_Tx": subs:wellKnown_Rx(){"id"},
              "Rx_role": "sensory", "Tx_role": "sensor",
              "name": ent:name+"-sensory", "channel_type":"subscription"
            }
          }
        )
      }
    
    rule on_subscription_established {
        select when wrangler subscription_added
    
        pre {
          role = event:attrs{"Rx_role"}.klog("Role: ")
        }
        
        if (role == "sensor") then
          event:send(
            {
              "eci": event:attrs{"Tx"},
              "eid": "sign_me_up",
              "domain": "sensor",
              "type": "identify_subscription",
              "attrs": {
                "name": ent:name,
                "eci": wrangler:myself(){"eci"}
              }
            }
          )
    
        always {
          raise self event "register_manager"
          attributes { "eci": event:attrs{"Tx"} }
          if (role == "sensor")
        }
      }
    
    rule register_sensor_manager {
        select when self register_manager
        always {
          ent:manager_eci := event:attrs{"eci"}
        }
      }
    
      rule auto_accept_subscriptions {
        select when wrangler inbound_pending_subscription_added
        fired {
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs
        }
      }
  
    rule update_profile {
      select when sensor profile_updated
  
      pre {
        name = event:attrs{"name"}
        location = event:attrs{"location"}
        temperature_threshold = event:attrs{"temperature_threshold"}.decode()
        recipient_phone_number = event:attrs{"recipient_phone_number"}
      }
      
      always {
        ent:name := name
        ent:location := location
        ent:temperature_threshold := temperature_threshold
        ent:recipient_phone_number := recipient_phone_number
  
        raise wovyn event "config" attributes
          {
            "recipient_phone_number": ent:recipient_phone_number,
            "temperature_threshold": ent:temperature_threshold
          }
      }
  
    }
    
    rule on_temperature_violation {
        select when sensor notify_high_temperature
        event:send(
            {
              "eci": ent:manager_eci,
              "eid": "too_hot",
              "domain": "sensor",
              "type": "temperature_violation",
              "attrs": event:attrs
            }
          )
      }
  }