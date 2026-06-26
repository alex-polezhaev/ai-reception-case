// portal.cpp - WiFiManager captive portal setup, styling, and connection handling.
#include "portal.h"
#include <WiFiManager.h>

void portal_start(WiFiManager &wm) {
    wm.setCustomHeadElement(
    R"rawliteral(
    <style>
        button {
            background-color: #59bd60;
            color: #fff;
            font-size: 1rem;
            font-weight: bold;
            cursor: pointer;
        }
        button:hover {
            background-color: rgba(194, 247, 217, 1)
        }
    </style>
    <script>
    document.addEventListener('DOMContentLoaded', () => {
        // Relabel the two generic WiFiManager buttons
        document.querySelectorAll('button').forEach(b => {
            const label = b.innerText.trim();
            if (label === 'Info') b.innerText = 'Developer Info';
            else if (label === 'Update') b.innerText = 'Update Firmware';
        });

        // Translate status messages
        const msgDiv = document.querySelector('.msg');
        if (msgDiv) {
            const msg = msgDiv.innerText.trim();
            if (msg === 'No AP set') {
                msgDiv.innerText = 'Device not configured';
            } else if (msg.startsWith('Saving Credentials')) {
                msgDiv.innerHTML =
                    'Saving settings<br/>' +
                    'Trying to connect to Wi-Fi.<br/>' +
                    'If it fails — connect to the access point and try again.';
            }
        }
    });
    document.addEventListener('DOMContentLoaded', () => {
        document.querySelectorAll('.msg').forEach(msgDiv => {
            const html = msgDiv.innerHTML.trim();
            // Handle: "Not connected to XXX"
            if (html.startsWith('<strong>Not connected</strong>') && html.includes('to')) {
                const ssid = html.split('to ')[1];
                msgDiv.innerHTML = `<strong>Not connected</strong> to ${ssid}`;
            }
            // Handle: "Not connected to XXX<br>AP not found"
            if (html.includes('Not connected') && html.includes('AP not found')) {
                const ssid = html.split('to ')[1].split('<br')[0];
                msgDiv.innerHTML = `<strong>Not connected</strong> to ${ssid}<br/>Access point not found`;
            }
        });
    });
    </script>
    )rawliteral"
    );

    // Menu setup
    std::vector<const char*> menu = {"wifi", "param", "info", "erase", "update"};
    wm.setMenu(menu);

    wm.setDebugOutput(true);
    wm.setTitle("Setup");
    wm.setConnectTimeout(10); // 10 seconds to connect

    // Generate unique Wi-Fi AP name based on full DEVICE_ID
    String deviceId = String(DEVICE_ID);
    String apName = "Ai-Reception-" + deviceId;

    // Waits for connection or configuration (portal opens automatically)
    if (!wm.autoConnect(apName.c_str())) {
        Serial.println("[WIFI_PORTAL] Failed to connect, restarting...");
        delay(2000);
        ESP.restart();
    }

    Serial.printf("[WIFI_PORTAL] Successfully connected to: %s IP: %s\n", WiFi.SSID().c_str(), WiFi.localIP().toString().c_str());
}