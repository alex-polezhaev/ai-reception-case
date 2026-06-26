.PHONY: erase dev prod

erase:
	platformio run --target erase \
	--environment esp32-s3-n16r8

dev:
ifndef DEVICE_ID
	$(error DEVICE_ID is required. Usage: make dev DEVICE_ID="YOUR-DEVICE-ID")
endif
	DEVICE_ID=$(DEVICE_ID) \
	SERVER_URL=http://your-dev-host.local:8080 \
	pio run -e esp32-s3-n16r8 --target upload

prod:
ifndef DEVICE_ID
	$(error DEVICE_ID is required. Usage: make prod DEVICE_ID="YOUR-DEVICE-ID")
endif
	DEVICE_ID=$(DEVICE_ID) \
	SERVER_URL=https://core.your-domain.example \
	pio run -e esp32-s3-n16r8 --target upload