from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('api', '0010_reward_stock_quantity_reward_valid_until')]
    operations = [migrations.AddField(model_name='activity', name='material_type', field=models.CharField(default='plastic', max_length=50))]