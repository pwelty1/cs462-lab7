ruleset manager_profile {
    meta {
        configure using
            account_sid = meta:rulesetConfig{"account_sid"}
            authtoken = meta:rulesetConfig{"authtoken"}
            recipient_phone_number = meta:rulesetConfig{"recipient_phone_number"}
            temperature_threshold = meta:rulesetConfig{"temperature_threshold"}
        
        shares get_config
        provides get_config    
    }

    global {
        get_config = function () {
            {
                "sid": account_sid,
                "authtoken": authtoken,
                "recipient_phone_number": recipient_phone_number,
                "temperature_threshold": temperature_threshold
            }
        }
    }
}