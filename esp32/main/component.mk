#
# "main" pseudo-component makefile.
#
# (Uses default behaviour of compiling all source files in directory, adding 'include' to include path.)

# embed files from the "certs" directory as binary data symbols
# in the app
COMPONENT_EMBED_TXTFILES := certs/aws-root-ca.pem certs/my-tls-certificate.pem.crt certs/my-tls-private.pem.key
