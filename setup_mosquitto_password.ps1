# Run this script to generate a password for mosquitto
docker run -it --rm -v ${PWD}/mosquitto/config:/mosquitto/config eclipse-mosquitto:2.0 mosquitto_passwd -c /mosquitto/config/pwfile smartbin
