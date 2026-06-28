import json
from channels.generic.websocket import AsyncWebsocketConsumer

class MapConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        await self.channel_layer.group_add("map_updates", self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("map_updates", self.channel_name)

    async def bin_update(self, event):
        message = event['message']
        await self.send(text_data=json.dumps({
            'type': 'bin_update',
            'message': message
        }))