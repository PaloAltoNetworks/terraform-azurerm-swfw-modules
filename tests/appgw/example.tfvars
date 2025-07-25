# GENERAL

subscription_id = null # TODO: Put the Azure Subscription ID here only in case you cannot use an environment variable!

region              = "North Europe"
resource_group_name = "appgw-example"
name_prefix         = "fosix-"
tags = {
  "createdBy"   = "Palo Alto Networks"
  "createdWith" = "Terraform"
}

# NETWORK

vnets = {
  transit = {
    name                    = "transit"
    address_space           = ["10.0.0.0/24"]
    network_security_groups = {}
    route_tables = {
      "rt" = {
        name = "rt"
        routes = {
          "udr" = {
            name           = "udr"
            address_prefix = "10.0.0.0/8"
            next_hop_type  = "None"
          }
        }
      }
    }
    subnets = {
      "appgw" = {
        name                    = "appgw"
        address_prefixes        = ["10.0.0.0/25"]
        route_table_key         = "rt"
        enable_appgw_delegation = true
      }
    }
  }
}

# LOAD BALANCING

appgws = {
  "public-empty" = {
    name       = "empty"
    vnet_key   = "transit"
    subnet_key = "appgw"
    public_ip = {
      name = "public-empty-ip"
    }
    listeners = {
      "http" = {
        name = "http"
        port = 80
      }
    }
    backend_settings = {
      http = {
        name     = "http"
        port     = 80
        protocol = "Http"
      }
    }
    rules = {
      "http" = {
        name         = "http"
        listener_key = "http"
        backend_key  = "http"
        priority     = 1
      }
    }
  }
  "public-http-minimum" = {
    name       = "appgw-http-minimum"
    vnet_key   = "transit"
    subnet_key = "appgw"
    zones      = []
    public_ip = {
      name = "pip-http-minimum"
    }
    listeners = {
      minimum = {
        name = "minimum-listener"
        port = 80
      }
    }
    backend_settings = {
      minimum = {
        name     = "minimum-backend"
        port     = 80
        protocol = "Http"
      }
    }
    rewrites = {
      minimum = {
        name = "minimum-set"
        rules = {
          "xff-strip-port" = {
            name     = "minimum-xff-strip-port"
            sequence = 100
            request_headers = {
              "X-Forwarded-For" = "{var_add_x_forwarded_for_proxy}"
            }
          }
        }
      }
    }
    rules = {
      minimum = {
        name         = "minimum-rule"
        priority     = 1
        backend_key  = "minimum"
        listener_key = "minimum"
        rewrite_key  = "minimum"
      }
    }
  }
  "public-http-existing" = {
    name       = "appgw-http-existing"
    vnet_key   = "transit"
    subnet_key = "appgw"
    zones      = ["1"]
    public_ip = {
      name   = "pip-existing"
      create = false
    }
    listeners = {
      existing = {
        name = "existing-listener"
        port = 80
      }
    }
    backend_settings = {
      existing = {
        name                      = "http-backend"
        port                      = 80
        protocol                  = "Http"
        timeout                   = 60
        use_cookie_based_affinity = true
      }
    }
    rewrites = {
      existing = {
        name = "existing-set"
        rules = {
          "xff-strip-port" = {
            name     = "existing-xff-strip-port"
            sequence = 100
            request_headers = {
              "X-Forwarded-For" = "{var_add_x_forwarded_for_proxy}"
            }
          }
        }
      }
    }
    rules = {
      existing = {
        name         = "existing-rule"
        priority     = 1
        backend_key  = "existing"
        listener_key = "existing"
        rewrite_key  = "existing"
      }
    }
  }
  "public-http-autoscale" = {
    name       = "appgw-http-autoscale"
    vnet_key   = "transit"
    subnet_key = "appgw"
    zones      = null
    public_ip = {
      name = "pip-http-autoscale"
    }
    capacity = {
      autoscale = {
        min = 2
        max = 20
      }
    }
    listeners = {
      http = {
        name = "http-listener"
        port = 80
      }
    }
    backend_settings = {
      http = {
        name                      = "http-backend"
        port                      = 80
        protocol                  = "Http"
        timeout                   = 60
        use_cookie_based_affinity = true
      }
    }
    rules = {
      http = {
        name         = "http-rule"
        priority     = 1
        backend_key  = "http"
        listener_key = "http"
      }
    }
  }
  "public-waf" = {
    name       = "appgw-waf"
    vnet_key   = "transit"
    subnet_key = "appgw"
    zones      = []
    public_ip = {
      name = "pip-waf"
    }
    capacity = {
      static = 4
    }
    enable_http2 = true
    waf = {
      prevention_mode  = true
      rule_set_type    = "OWASP"
      rule_set_version = "3.2"
    }
    listeners = {
      waf = {
        name = "waf-listener"
        port = 80
      }
    }
    backend_settings = {
      waf = {
        name                      = "waf-backend"
        port                      = 80
        protocol                  = "Http"
        timeout                   = 60
        use_cookie_based_affinity = true
      }
    }
    rewrites = {
      waf = {
        name = "waf-set"
        rules = {
          "xff-strip-port" = {
            name     = "waf-xff-strip-port"
            sequence = 100
            request_headers = {
              "X-Forwarded-For" = "{var_add_x_forwarded_for_proxy}"
            }
          }
        }
      }
    }
    rules = {
      minimum = {
        name         = "waf-rule"
        priority     = 1
        backend_key  = "waf"
        listener_key = "waf"
        rewrite_key  = "waf"
      }
    }
  }
  # If you test example for Application Gateway with SSL,
  # you need to created directory files and create keys and certs using commands:
  # 1. Create CA private key and certificate:
  #    openssl genrsa 2048 > ca-key1.pem
  #    openssl req -new -x509 -nodes -days 365000 -key ca-key1.pem -out ca-cert1.pem
  #    openssl genrsa 2048 > ca-key2.pem
  #    openssl req -new -x509 -nodes -days 365000 -key ca-key2.pem -out ca-cert2.pem
  # 2. Create server certificate:
  #    openssl req -newkey rsa:2048 -nodes -keyout test1.key -x509 -days 365 -CA ca-cert1.pem -CAkey ca-key1.pem -out test1.crt
  #    openssl req -newkey rsa:2048 -nodes -keyout test2.key -x509 -days 365 -CA ca-cert2.pem -CAkey ca-key2.pem -out test2.crt
  # 3. Create PFX file with key and certificate:
  #    openssl pkcs12 -inkey test1.key -in test1.crt -export -out test1.pfx
  #    openssl pkcs12 -inkey test2.key -in test2.crt -export -out test2.pfx
  # "public-ssl-custom" = {
  #   name       = "appgw-ssl-custom"
  #   vnet_key   = "transit"
  #   subnet_key = "appgw"
  #   zones      = ["1", "2", "3"]
  #   public_ip = {
  #     name = "pip-ssl-custom"
  #   }
  #   global_ssl_policy = {
  #     type                 = "Custom"
  #     min_protocol_version = "TLSv1_0"
  #     cipher_suites = ["TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA", "TLS_DHE_DSS_WITH_AES_128_CBC_SHA",
  #       "TLS_DHE_DSS_WITH_AES_128_CBC_SHA256", "TLS_DHE_DSS_WITH_AES_256_CBC_SHA", "TLS_DHE_DSS_WITH_AES_256_CBC_SHA256",
  #       "TLS_DHE_RSA_WITH_AES_128_CBC_SHA", "TLS_DHE_RSA_WITH_AES_128_GCM_SHA256", "TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
  #       "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384", "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA", "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256",
  #       "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256", "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA",
  #       "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384", "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
  #       "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA", "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256", "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
  #       "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA", "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384", "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
  #       "TLS_RSA_WITH_3DES_EDE_CBC_SHA", "TLS_RSA_WITH_AES_128_CBC_SHA", "TLS_RSA_WITH_AES_128_CBC_SHA256",
  #       "TLS_RSA_WITH_AES_128_GCM_SHA256", "TLS_RSA_WITH_AES_256_CBC_SHA", "TLS_RSA_WITH_AES_256_CBC_SHA256",
  #     "TLS_RSA_WITH_AES_256_GCM_SHA384"]
  #   }
  #   ssl_profiles = {
  #     profile1 = {
  #       name                            = "appgw-ssl-profile1"
  #       ssl_policy_min_protocol_version = "TLSv1_1"
  #       ssl_policy_cipher_suites = ["TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA", "TLS_DHE_DSS_WITH_AES_128_CBC_SHA",
  #         "TLS_DHE_DSS_WITH_AES_128_CBC_SHA256", "TLS_DHE_DSS_WITH_AES_256_CBC_SHA", "TLS_DHE_DSS_WITH_AES_256_CBC_SHA256",
  #         "TLS_DHE_RSA_WITH_AES_128_CBC_SHA", "TLS_DHE_RSA_WITH_AES_128_GCM_SHA256", "TLS_DHE_RSA_WITH_AES_256_CBC_SHA",
  #         "TLS_DHE_RSA_WITH_AES_256_GCM_SHA384", "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA",
  #         "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256", "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
  #         "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA", "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384",
  #         "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384", "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA",
  #         "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256", "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256", "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA",
  #       "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384", "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"]
  #     }
  #     profile2 = {
  #       name                            = "appgw-ssl-profile2"
  #       ssl_policy_min_protocol_version = "TLSv1_2"
  #       ssl_policy_cipher_suites = ["TLS_RSA_WITH_3DES_EDE_CBC_SHA", "TLS_RSA_WITH_AES_128_CBC_SHA",
  #         "TLS_RSA_WITH_AES_128_CBC_SHA256", "TLS_RSA_WITH_AES_128_GCM_SHA256", "TLS_RSA_WITH_AES_256_CBC_SHA",
  #       "TLS_RSA_WITH_AES_256_CBC_SHA256", "TLS_RSA_WITH_AES_256_GCM_SHA384"]
  #     }
  #   }
  #   frontend_ip_configuration_name = "public_ipconfig"
  #   listeners = {
  #     http = {
  #       name = "http-listener"
  #       port = 80
  #     }
  #     https1 = {
  #       name                 = "https1-listener"
  #       port                 = 443
  #       protocol             = "Https"
  #       ssl_profile_name     = "appgw-ssl-profile1"
  #       ssl_certificate_path = "./files/test1.pfx"
  #       ssl_certificate_pass = ""
  #       host_names           = ["test1.appgw.local"]
  #     }
  #     https2 = {
  #       name                 = "https2-listener"
  #       port                 = 443
  #       protocol             = "Https"
  #       ssl_profile_name     = "appgw-ssl-profile2"
  #       ssl_certificate_path = "./files/test2.pfx"
  #       ssl_certificate_pass = ""
  #       host_names           = ["test2.appgw.local"]
  #     }
  #     redirect_listener = {
  #       name = "redirect-listener-listener"
  #       port = 521
  #     }
  #     redirect_url = {
  #       name = "redirect-url-listener"
  #       port = 522
  #     }
  #     path_based_backend = {
  #       name = "path-backend-listener"
  #       port = 641
  #     }
  #     path_based_redirect_listener = {
  #       name = "path-redirect-listener-listener"
  #       port = 642
  #     }
  #     path_based_redirect_url = {
  #       name = "path-redirect-rul-listener"
  #       port = 643
  #     }
  #   }
  #   backend_pool = {
  #     name = "vmseries-pool"
  #   }
  #   backend_settings = {
  #     http = {
  #       name                      = "http-settings"
  #       port                      = 80
  #       protocol                  = "Http"
  #       timeout                   = 60
  #       use_cookie_based_affinity = true
  #       probe_key                 = "http"
  #     }
  #     https1 = {
  #       name                      = "https1-settings"
  #       port                      = 481
  #       protocol                  = "Https"
  #       timeout                   = 60
  #       use_cookie_based_affinity = true
  #       hostname_from_backend     = false
  #       hostname                  = "test1.appgw.local"
  #       root_certs = {
  #         test = {
  #           name = "https-application-test1"
  #           path = "./files/ca-cert1.pem"
  #         }
  #       }
  #       probe_key = "https1"
  #     }
  #     https2 = {
  #       name                      = "https2-settings"
  #       port                      = 482
  #       protocol                  = "Https"
  #       timeout                   = 60
  #       use_cookie_based_affinity = true
  #       hostname_from_backend     = false
  #       hostname                  = "test2.appgw.local"
  #       root_certs = {
  #         test = {
  #           name = "https-application-test2"
  #           path = "./files/ca-cert2.pem"
  #         }
  #       }
  #       probe_key = "https2"
  #     }
  #   }
  #   probes = {
  #     http = {
  #       name     = "http-probe"
  #       path     = "/"
  #       protocol = "Http"
  #       timeout  = 10
  #       host     = "127.0.0.1"
  #     }
  #     https1 = {
  #       name     = "https-probe1"
  #       path     = "/"
  #       protocol = "Https"
  #       timeout  = 10
  #     }
  #     https2 = {
  #       name     = "https-probe2"
  #       path     = "/"
  #       protocol = "Https"
  #       timeout  = 10
  #     }
  #   }
  #   rewrites = {
  #     http = {
  #       name = "http-set"
  #       rules = {
  #         "xff-strip-port" = {
  #           name     = "http-xff-strip-port"
  #           sequence = 100
  #           request_headers = {
  #             "X-Forwarded-For" = "{var_add_x_forwarded_for_proxy}"
  #           }
  #         }
  #       }
  #     }
  #     https1 = {
  #       name = "https1-set"
  #       rules = {
  #         "xff-strip-port" = {
  #           name     = "https1-xff-strip-port"
  #           sequence = 100
  #           conditions = {
  #             "http_resp_X-Forwarded-Proto" = {
  #               pattern     = "https"
  #               ignore_case = true
  #               negate      = true
  #             }
  #           }
  #           request_headers = {
  #             "X-Forwarded-For"   = "{var_add_x_forwarded_for_proxy}"
  #             "X-Forwarded-Proto" = "https"
  #           }
  #         }
  #       }
  #     }
  #     https2 = {
  #       name = "https2-set"
  #       rules = {
  #         "xff-strip-port" = {
  #           name     = "https2-xff-strip-port"
  #           sequence = 100
  #           conditions = {
  #             "http_resp_X-Forwarded-Proto" = {
  #               pattern     = "https"
  #               ignore_case = true
  #               negate      = true
  #             }
  #           }
  #           request_headers = {
  #             "X-Forwarded-For"   = "{var_add_x_forwarded_for_proxy}"
  #             "X-Forwarded-Proto" = "https"
  #           }
  #         }
  #       }
  #     }
  #   }
  #   redirects = {
  #     redirect_listener = {
  #       name                 = "listener-redirect"
  #       type                 = "Permanent"
  #       target_listener_key  = "http"
  #       include_path         = true
  #       include_query_string = true
  #     }
  #     redirect_url = {
  #       name                 = "url-redirect"
  #       type                 = "Temporary"
  #       target_url           = "http://example.com"
  #       include_path         = true
  #       include_query_string = true
  #     }
  #   }
  #   url_path_maps = {
  #     path_based_backend = {
  #       name        = "backend-map"
  #       backend_key = "http"
  #       path_rules = {
  #         http = {
  #           paths       = ["/plaintext"]
  #           backend_key = "http"
  #         }
  #         https = {
  #           paths       = ["/secure"]
  #           backend_key = "https1"
  #         }
  #       }
  #     }
  #     path_based_redirect_listener = {
  #       name        = "redirect-listener-map"
  #       backend_key = "http"
  #       path_rules = {
  #         http = {
  #           paths        = ["/redirect"]
  #           redirect_key = "redirect_listener"
  #         }
  #       }
  #     }
  #     path_based_redirect_url = {
  #       name        = "redirect-url-map"
  #       backend_key = "http"
  #       path_rules = {
  #         http = {
  #           paths        = ["/redirect"]
  #           redirect_key = "redirect_url"
  #         }
  #       }
  #     }
  #   }
  #   rules = {
  #     http = {
  #       name         = "http-rule"
  #       priority     = 1
  #       backend_key  = "http"
  #       listener_key = "http"
  #       rewrite_key  = "http"
  #     }
  #     https1 = {
  #       name         = "https1-rule"
  #       priority     = 2
  #       backend_key  = "https1"
  #       listener_key = "https1"
  #       rewrite_key  = "https1"
  #     }
  #     https2 = {
  #       name         = "https2-rule"
  #       priority     = 3
  #       backend_key  = "https2"
  #       listener_key = "https2"
  #       rewrite_key  = "https2"
  #     }
  #     redirect_listener = {
  #       name         = "redirect-listener-rule"
  #       priority     = 4
  #       listener_key = "redirect_listener"
  #       redirect_key = "redirect_listener"
  #     }
  #     redirect_url = {
  #       name         = "redirect-url-rule"
  #       priority     = 5
  #       listener_key = "redirect_url"
  #       redirect_key = "redirect_url"
  #     }
  #     path_based_backend = {
  #       name             = "path-based-backend-rule"
  #       priority         = 6
  #       listener_key     = "path_based_backend"
  #       url_path_map_key = "path_based_backend"
  #     }
  #     path_based_redirect_listener = {
  #       name             = "path-redirect-listener-rule"
  #       priority         = 7
  #       listener_key     = "path_based_redirect_listener"
  #       url_path_map_key = "path_based_redirect_listener"
  #     }
  #     path_based_redirect_url = {
  #       name             = "path-redirect-rul-rule"
  #       priority         = 8
  #       listener_key     = "path_based_redirect_url"
  #       url_path_map_key = "path_based_redirect_url"
  #     }
  #   }
  # }
  # "public-ssl-predefined" = {
  #   name       = "appgw-ssl-predefined"
  #   vnet_key   = "transit"
  #   subnet_key = "appgw"
  #   public_ip = {
  #     name = "pip-ssl-predefined"
  #   }
  #   global_ssl_policy = {
  #     type = "Predefined"
  #     name = "AppGwSslPolicy20170401"
  #   }
  #   ssl_profiles = {
  #     profile1 = {
  #       name            = "appgw-ssl-profile1"
  #       ssl_policy_name = "AppGwSslPolicy20170401S"
  #     }
  #   }
  #   listeners = {
  #     https1 = {
  #       name                 = "https1-listener"
  #       port                 = 443
  #       protocol             = "Https"
  #       ssl_profile_name     = "appgw-ssl-profile1"
  #       ssl_certificate_path = "./files/test1.pfx"
  #       ssl_certificate_pass = ""
  #       host_names           = ["test1.appgw.local"]
  #     }
  #     https2 = {
  #       name                 = "https2-listener"
  #       port                 = 443
  #       protocol             = "Https"
  #       ssl_certificate_path = "./files/test2.pfx"
  #       ssl_certificate_pass = ""
  #       host_names           = ["test2.appgw.local"]
  #     }
  #   }
  #   backend_pool = {
  #     name = "vmseries-pool-custom"
  #   }
  #   backend_settings = {
  #     https1 = {
  #       name                      = "https1-settings"
  #       port                      = 481
  #       protocol                  = "Https"
  #       timeout                   = 60
  #       use_cookie_based_affinity = true
  #       hostname_from_backend     = false
  #       hostname                  = "test1.appgw.local"
  #       root_certs = {
  #         test = {
  #           name = "https-application-test1"
  #           path = "./files/ca-cert1.pem"
  #         }
  #       }
  #     }
  #     https2 = {
  #       name                      = "https2-settings"
  #       port                      = 482
  #       protocol                  = "Https"
  #       timeout                   = 60
  #       use_cookie_based_affinity = true
  #       hostname_from_backend     = false
  #       hostname                  = "test2.appgw.local"
  #       root_certs = {
  #         test = {
  #           name = "https-application-test2"
  #           path = "./files/ca-cert2.pem"
  #         }
  #       }
  #     }
  #   }
  #   rewrites = {
  #     https1 = {
  #       name = "https1-set"
  #       rules = {
  #         "xff-strip-port" = {
  #           name     = "https1-xff-strip-port"
  #           sequence = 100
  #           conditions = {
  #             "http_resp_X-Forwarded-Proto" = {
  #               pattern     = "https"
  #               ignore_case = true
  #               negate      = true
  #             }
  #           }
  #           request_headers = {
  #             "X-Forwarded-For"   = "{var_add_x_forwarded_for_proxy}"
  #             "X-Forwarded-Proto" = "https"
  #           }
  #         }
  #       }
  #     }
  #     https2 = {
  #       name = "https2-set"
  #       rules = {
  #         "xff-strip-port" = {
  #           name     = "https2-xff-strip-port"
  #           sequence = 100
  #           conditions = {
  #             "http_resp_X-Forwarded-Proto" = {
  #               pattern     = "https"
  #               ignore_case = true
  #               negate      = true
  #             }
  #           }
  #           request_headers = {
  #             "X-Forwarded-For"   = "{var_add_x_forwarded_for_proxy}"
  #             "X-Forwarded-Proto" = "https"
  #           }
  #         }
  #       }
  #     }
  #   }
  #   rules = {
  #     https1 = {
  #       name         = "https1-rule"
  #       priority     = 2
  #       backend_key  = "https1"
  #       listener_key = "https1"
  #       rewrite_key  = "https1"
  #     }
  #     https2 = {
  #       name         = "https2-rule"
  #       priority     = 3
  #       backend_key  = "https2"
  #       listener_key = "https2"
  #       rewrite_key  = "https2"
  #     }
  #   }
  # }
}
