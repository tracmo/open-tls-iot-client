idf_component_register(

    # header folders
    INCLUDE_DIRS "."

    # src folders
    # NOTE: DO NOT use SRCS the same time, either SRCS or SRC_DIRS would be ignored
    SRC_DIRS "."

    # embed files
    EMBED_TXTFILES "certs/aws-root-ca.pem"
                    "certs/my-tls-certificate.pem.crt"
                    "certs/my-tls-private.pem.key"
)
