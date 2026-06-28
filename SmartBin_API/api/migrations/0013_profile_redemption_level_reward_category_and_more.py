from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('api', '0012_profile_last_activity_date_profile_streak_count_and_more')]
    operations = [migrations.AddField(model_name='profile', name='redemption_level', field=models.IntegerField(default=1)), migrations.AddField(model_name='reward', name='category', field=models.CharField(default='General', max_length=50)), migrations.AddField(model_name='reward', name='dynamic_limit', field=models.IntegerField(default=-1)), migrations.AddField(model_name='reward', name='tier', field=models.IntegerField(default=1))]