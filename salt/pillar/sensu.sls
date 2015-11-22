role: sensu
sensu:
  server:
    install_gems:
      - mail
      - timeout
  rabbitmq:
    host: chewie.infra.nucleoid.com
    user: sensu
    password: secret
  api:
    password: |
        -----BEGIN PGP MESSAGE-----
        Version: GnuPG v1
        
        hQEMAynhcJsHetnQAQf9GzDyDf8eiJJiXxPlEaUoak6riT/o9ApiPG1rUhNaK2tQ
        p7wto4kal9zqdNiDCYnvu/nfsE3cnUCG1ou/GRNS1VtPHQLrO25ke0iMAjseqO0w
        rYXndiNAW/xG5DEhfRkY9JZcLQJgAawbq2ZeajdKfZJEyRo780pFQw04ZyC/TK6l
        S2uZhL6nwB0sxEroiscoddp9wFfuUW9Sr2cCwS4elgmzbzgw+2OYqOfDOp9HrRYP
        0y7+PwTsbvtdY+Dv7jcouJRfq0o3acSixKiAN3YjlkVldS4l9117Gv+5QPJIaN44
        CIVsKF5HwAo+VXOX/v++MoTR0w41bAPcUIE9eTuwY9JBAehiJpq7MsOKVGsqyHEO
        9iwsgyvkn/Kn1yD9u+HjHOLYWYKoHrEU1hzSGtLZ4L2xUiyH1KLMXRINHkHIwEhd
        3To=
        =5X9L
        -----END PGP MESSAGE-----
  ssl:
    enable: False
    cert_pem: |
        -----BEGIN CERTIFICATE-----
        MIIC3TCCAcWgAwIBAgIBATANBgkqhkiG9w0BAQUFADASMRAwDgYDVQQDEwdTZW5z
        dUNBMB4XDTE1MDgyMzE3MjEyMVoXDTIwMDgyMTE3MjEyMVowITEOMAwGA1UEAwwF
        c2Vuc3UxDzANBgNVBAoMBnNlcnZlcjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
        AQoCggEBAMiKqdGe+YNJdABEIX+Cyb9K3Ydc1vaC/W8tLyYcISAzKEAz8ul91N1F
        htKGg90JapwHTTgRrnScKKspPyDgL+vOW6UOYkpOmqlVNstjgRM2qhtkwXHR9hEq
        psfBibxxTHjdAScNcSKXZB8EtqHNi6Q8KZ2Uc0APJbWUsSMHyH5IF/wp2YYZYgzj
        ix8E2iskH1dJoAbHDX0m5Sbc56iYKAy1aSFzVMcbEIX5iDlpYOZV+oW5SyOKGPkL
        Za0YfgshCl7thJGFjh9sd4AZ/eG8DEHg6jhNMDo56w4JZu/CIhcOOHkz5Oe3AtDl
        gwYrRt1HmuRnhRO9EmdU9b6RrVuIb2kCAwEAAaMvMC0wCQYDVR0TBAIwADALBgNV
        HQ8EBAMCBSAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDQYJKoZIhvcNAQEFBQADggEB
        AGJZvw63A2lp5hcLeD7OsxH7+jAzuFFvqtzIGe9UZfI176NhGu14ANu8F7po7xpq
        IX0EgzX3uHBgftj1zv/LrWdFmfRDMoxQ3naZgp+3kCZ5CInSc6XoGdIJiK9GH6R5
        3Je3EB4/oG5kYrgP7STtpJX4CRhyCVIUD8Zahlo8iTXjqHaj0QNyzGYwi775DoiD
        7Y0CPUg60hPVPRCxApknQyWTSqdcJbVC4qCWCulw5NFCVS1qjOp8os/zUTK+csjU
        +Te2lUck2jLRutE+NWNmtUxUOLRH6ywSE/k6U49Q7MzOi3AmTHtait1QTxf3KOns
        JMDwPAv8wK9rQoHrLnwFHOs=
        -----END CERTIFICATE-----
    key_pem: |
        -----BEGIN RSA PRIVATE KEY-----
        MIIEpQIBAAKCAQEAyIqp0Z75g0l0AEQhf4LJv0rdh1zW9oL9by0vJhwhIDMoQDPy
        6X3U3UWG0oaD3QlqnAdNOBGudJwoqyk/IOAv685bpQ5iSk6aqVU2y2OBEzaqG2TB
        cdH2ESqmx8GJvHFMeN0BJw1xIpdkHwS2oc2LpDwpnZRzQA8ltZSxIwfIfkgX/CnZ
        hhliDOOLHwTaKyQfV0mgBscNfSblJtznqJgoDLVpIXNUxxsQhfmIOWlg5lX6hblL
        I4oY+QtlrRh+CyEKXu2EkYWOH2x3gBn94bwMQeDqOE0wOjnrDglm78IiFw44eTPk
        57cC0OWDBitG3Uea5GeFE70SZ1T1vpGtW4hvaQIDAQABAoIBAQCrh69pVQkmepV2
        BNCCOGRH8sk5FvfnMnODvKovdq/+0sMC52xGuxJvkSCYweXYEk3V14j9BGKr60X9
        4PHWNOvITmGk9ICt/j3byL9tiFbHEGK/u5aavHQ0ir7M7YXaYS5/0slBlgXHCKbi
        wS1ViHKAr9UIrAlIKayfe+dnhyi+mXfZT+xtaXnU70XKdgxAq/2EgMvHzLgbnqbP
        EPvUgaFHqc/aDYVRpBuRSIClkP+rX0h0ae4thaZlEoQW9z03PoWtpPHFiNMrZ6Dm
        HV48ePS/2euBzi3xiyEK/B1DkpsnDVJKYOmp+hpNv6r7BaOJLhq4uPB7CWaXDe1b
        PtNXSnFhAoGBAOoeXYJXidPOFn947JypQ9QZnEjmVBCSu+O6AsdbSASoNBwLZM+B
        wK0X8aKoPM9+ULwumaZO5tOR2dRBoLpuT4djHiDWYOJCAIcYsN9FjmAvQnHR880y
        8L/YmGDjA/Z+y3Qv8ao7nRTysP/GZVl9twlTYUrO6tBcrOZ5QrCqFPFvAoGBANtI
        62fRQp3aXIrIRhjxFlZYZE5IV85xF125BzvJpyNQSYO5hp0YcfdVwMqA6JbUf1Ne
        F0P6pzLwx6XouxQtzu6F+R12ji5PzLNKl66DOpA6vYvRwQmXoVoqKkp7JuKXKZ/m
        Fp/lsxm15ew89Qb9Wfe5Mixww6L3dH0gNN7/uBCnAoGBAKhfsEaWaGRwuhNxR1Ig
        Fc0Loi93nwvQS9qqo2b2yiO3SMrGkvj9yzFxn/GoZxufL7c3GH/YDQApy+xwSoTp
        4r5u1XMuWr0+VJzUcBgTMSMRugqbwWhZc3W181jyy53ScMYd2QLiHsW7CPral3c2
        B5ZoZfdkOtIhZKPYn9Lob2l3AoGBAMGCxgqlxi3bBxOJzSIxjs6/zjSu7p3FeyNA
        JzwBpjcpoNZXoI19hwUHbczGmXqRJ5OAUvOwfGAdz3F/waf7DMO9AquXdb00uqX1
        y4k7UTD6RU7f2YQHhWI2F4AG0bfgQeFTgN+2KqkjtjUVTf3PEdfkXHyPPnXP/cJ1
        63JnJB29AoGAITN0OTMwfD4ZhgcWd5UO3OpJ6rIV7GJ5KzjjQrD38BnvAmVz9R4e
        b3yIv64jvmrfgbc39KF18QOv8//eIoglrAobRCVSMf0samJ6UInm/PiTn0sborcm
        0rVD4MamGKojQVceILVyBsOYQPPUofufeS5xmzj7oJlIaI1sNStM3AA=
        -----END RSA PRIVATE KEY-----
  uchiwa:
    sites:
      Sensu:
        user: admin
        password: secret
        host: 127.0.0.1
        ssl: False

  client:
    embedded_ruby: true
    nagios_plugins: true

  slack:
    webhook_url: https://hooks.slack.com/services/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

