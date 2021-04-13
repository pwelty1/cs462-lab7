ruleset manage_sensors {
    meta {
      use module io.picolabs.wrangler alias wrangler
      use module io.picolabs.subscription alias subs    
      use module manager_profile alias profile
      use module com.twilio alias twilio
        with 
        account_sid = meta:rulesetConfig{"account_sid"}
        authtoken = meta:rulesetConfig{"authtoken"}
  
      
      shares get_profile, get_subscriptions, get_sensors, already_contains, get_all_temperatures
    }
  
    global {
      default_temp_threshold = 100
  
      create_pico_name = function () {
        <<Sensor #{wrangler:children().length() + 1}>>
      }
  
      already_contains = function (name) {
        ent:sensors.keys().any(function(v) {
          v == name
        })
      }
  
      get_sensors = function () {
        ent:sensors
      }

      get_subscriptions = function () {
        subs:established()
      }
  
      get_profile = function () {
        profile:get_config()
      }
  
      get_all_temperatures = function () {
        ent:sensor_subs.values().map(function (val) {
            wrangler:picoQuery(val{"eci"}, "store.temperature", "temperatures")
          })
      }
    }
  
    rule init {
      select when wrangler ruleset_installed where event:attrs{"rids"} >< ctx:rid
      
      always {
        ent:sensors := {}
        ent:sensor_subs := {}
        // raise sensor event "new_sensor"
      }
    }
  
    rule trigger_new_sensor_creation {
      select when sensor new_sensor
  
      always {
          ent:name := create_pico_name()
        raise wrangler event "new_child_request"
          attributes 
            {
              "name": ent:name
            }
        if not already_contains(create_pico_name()).klog("already in sensors?")
      }
    }
  
    rule on_child_created {
      select when wrangler new_child_created
  
      pre {
        eci = event:attrs{"eci"}
        name = event:attrs{"name"}
      }
  
      fired {
        raise sensor event "temperature_store_child"
          attributes event:attrs
      }
    }
  
    rule on_child_initialized {
      select when wrangler child_initialized
      
      pre {
        name = event:attrs{"name"}
        eci = event:attrs{"eci"}
      }
  
      event:send({
        "eci": eci,
        "eid": "initialize-pico",
        "domain": "sensor", "type": "profile_updated",
        "attrs": {
          "name": name,
          "location": "default",
          "temperature_threshold": get_profile(){"temperature_threshold"},
          "recipient_phone_number": get_profile(){"recipient_phone_number"}
        }
      })
    }
  
    rule install_temperature_store_child {
      select when sensor temperature_store_child
      
      pre {
        eci = event:attrs{"eci"}
        name = event:attrs{"name"}
      }
      
      event:send(
        {
          "eci": eci,
          "eid": "install-ruleset",
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": meta:rulesetURI,
            "rid": "temperature_store",
            "config": {}
          }
        }
      )
  
      always {
        raise sensor event "twilio_child"
          attributes event:attrs
      }
    }
  
    rule install_twilio_in_child {
      select when sensor twilio_child
  
      pre {
        eci = event:attrs{"eci"}
        name = event:attrs{"name"}
      }
  
      event:send(
        {
          "eci": eci,
          "eid": "install-ruleset",
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": meta:rulesetURI,
            "rid": "twilio_ruleset",
            "config": {}
          }
        }
      )
  
      always {
        raise sensor event "wovyn_base_child"
          attributes event:attrs
      }
    }
  
    rule install_wovyn_base_in_child {
      select when sensor wovyn_base_child
  
      pre {
        eci = event:attrs{"eci"}
        name = event:attrs{"name"}
        configuration = get_profile()
      }
  
      event:send(
        {
          "eci": eci,
          "eid": "install-ruleset",
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": meta:rulesetURI,
            "rid": "wovyn_base",
            "config": configuration
          }
        }
      )
  
      always {
        raise sensor event "sensor_profile_child"
          attributes event:attrs
      }
    }
  
    rule install_sensor_profile_in_child {
      select when sensor sensor_profile_child
  
      pre {
        eci = event:attrs{"eci"}
        name = event:attrs{"name"}
      }
  
      event:send(
        {
          "eci": eci,
          "eid": "install-ruleset",
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": meta:rulesetURI,
            "rid": "sensor_profile",
            "config": {}
          }
        }
      )
  
      always {
        raise sensor event "emitter_child"
          attributes event:attrs
      }
    }
  
    rule install_emiter_in_child {
      select when sensor emitter_child
  
      pre {
        eci = event:attrs{"eci"}
        name = event:attrs{"name"}
      }
  
      event:send(
        {
          "eci": eci,
          "eid": "install-ruleset",
          "domain": "wrangler", "type": "install_ruleset_request",
          "attrs": {
            "absoluteURL": meta:rulesetURI,
            "rid": "io.picolabs.wovyn.emitter",
            "config": {}
          }
        }
      )
  
    //   always {
    //     raise sensor event "store_new_sensor"
    //       attributes event:attrs
    //   }
    }

    rule identify_new_child {
        select when sensor identify_child
    
        pre {
          name = event:attrs{"name"}
          eci = event:attrs{"eci"}
          wellKnown_eci = event:attrs{"wellKnown_eci"}
        }
    
        always {
          ent:sensors{ent:name} := {
            "eci": eci,
            "wellKnown_eci": wellKnown_eci
          }
        }
      }
    
    rule identify_new_subscription {
        select when sensor identify_subscription
        pre {
          name = event:attrs{"name"}
          eci = event:attrs{"eci"}
          channelTx = event:attrs{"Tx"}
        }
    
        always {
          ent:sensor_subs{channelTx} := {
            "name": name,
            "eci": eci
          }
        }
    }
  
    rule store_new_sensor {
      select when sensor store_new_sensor
  
      pre {
        name = event:attrs{"name"}
        eci = event:attrs{"eci"}
      }
  
      always {
        ent:sensors{name} := eci
      }
    }
  
    rule clear_sensors {
      select when sensor clear_sensors
  
      always {
        ent:sensors := {}
      }
    }
  
    rule remove_sensor {
      select when sensor unneeded_sensor
  
      pre {
        name = event:attrs{"name"}
        eci = get_sensors(){name}
      }
  
      always {
        clear ent:sensors{name}
        raise wrangler event "child_deletion_request"
          attributes {"eci": eci}
      }
    }

    rule auto_accept_subscriptions {
        select when wrangler inbound_pending_subscription_added
        fired {
          raise wrangler event "pending_subscription_approval"
            attributes event:attrs
        }
      }
    
    rule notify_of_temperature_violation {
        select when sensor notify_high_temperature
        pre {
          recipient = get_profile(){"recipient_phone_number"}
          message = event:attrs{"message"}
        }
    
        twilio:sendMessage(recipient, message)
            setting(response)
    
      }
  
  }