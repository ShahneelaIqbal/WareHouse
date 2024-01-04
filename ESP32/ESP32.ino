#include <Arduino.h>
#include <HardwareSerial.h>
#include <PubSubClient.h>
#include <WiFi.h>
#include <HTTPClient.h>

const char* ssid = "noEntry1";
const char* password = "noEntry153";
const char* firebase_project_id = "warehouse-system-a4891-default-rtdb";
const char* firebase_auth_token = "6tZeowFYqOPfLFd5frpGMqIaNqrcNEP1IslqqMFH";
const char* mqtt_server = "test.mosquitto.org";

const char* mqtt_client_id = "esp32-client";
const char* mqtt_topic_xxx = "SensorValue2022CS";
const char* mqtt_topic_alert = "State2022CS";

HardwareSerial uartSerial(2); // Using UART2 for communication

WiFiClient wifiClient;
PubSubClient mqttClient(wifiClient);


void setup() {
  Serial.begin(115200);
  uartSerial.begin(9600, SERIAL_8N1, 16, 17); // RX, TX pins for UART2
  connectToWifi();
  mqttClient.setCallback(callback);
  connectToBroker();
   
}

void connectToWifi()
{
  // Connect to WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected to WiFi");
}

void connectToBroker()
{
  // Connect to MQTT
  mqttClient.setServer(mqtt_server, 1883);
  while (!mqttClient.connected()) {
    if (mqttClient.connect(mqtt_client_id))
    {
      mqttClient.subscribe("Intrupt2022CS");
    }
    else
    {
      Serial.print("Failed to connect to MQTT, rc=");
      Serial.println(mqttClient.state());
      delay(1000);
    }
  }
}

void loop() {
  if (WiFi.status() != WL_CONNECTED)
  {
    connectToWifi();
  }
  if (!mqttClient.connected())
  {
    connectToBroker();
  }
  // Check for data from UART
  if (uartSerial.available() > 0)
  {
    String data = uartSerial.readStringUntil('\n');
    processUARTData(data);
  }

  // Check for messages from MQTT
  mqttClient.loop();
}

void processUARTData(String data) {
  int value;
  int alert;

  // Parse the received data
  if (sscanf(data.c_str(), "%d-%d", &value, &alert) == 2) {
    // Separate value and alert
    Serial.print("Alert: ");
    Serial.print(value);
    Serial.println();
    
    if (alert == 1) {
      mqttClient.publish(mqtt_topic_alert, "C");
    } else if (alert == 0) {
      mqttClient.publish(mqtt_topic_alert, "N");
    }
    

    // Map value to the range 0-100
    int mappedValue = map(value, 0, 160, 0, 100);

    // Publish mapped value to MQTT
    mqttClient.publish(mqtt_topic_xxx, String(mappedValue).c_str());
    String firebase_url = String("https://") + firebase_project_id + String(".firebaseio.com/data.json?auth=") + firebase_auth_token;
    String json_data = "{\"value\": " + String(value) + ", \"alert\": " + String(alert) + "}";
     sendDataToFirebase(firebase_url, json_data);
  }
}
void sendDataToFirebase(String firebase_url, String json_data) {
  HTTPClient http;

  // Post data to Firebase
  http.begin(firebase_url);
  http.addHeader("Content-Type", "application/json");
  int httpCode = http.POST(json_data);

  if (httpCode == HTTP_CODE_OK) {
    Serial.println("Data sent to Firebase successfully");
  } else {
    Serial.println("Error sending data to Firebase");
    Serial.println(httpCode);
  }

  http.end();
}
void callback(char* topic, byte* payload, unsigned int length) {
  // Handle messages from MQTT

  Serial.print("Message arrived on topic: ");
  Serial.print(topic);
  Serial.print(". Message: ");

  String messageTemp;

  for (int i = 0; i < length; i++) {
    messageTemp += (char)payload[i];
  }
  Serial.print(messageTemp);
  Serial.println();
  if (messageTemp == "A" || messageTemp == "B")
  {
    // Send the entire payload through UART
    for (int i = 0; i < length; i++) {
      uartSerial.write(payload[i]);
    }
  }
  uartSerial.println();  // Move to the next line
}
