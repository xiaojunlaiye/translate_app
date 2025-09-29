curl -X POST http://summer.pink:8888/translation/translate \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "今天天气不错，我们去公园散步吧。",
    "target_lang": "English"
  }'
