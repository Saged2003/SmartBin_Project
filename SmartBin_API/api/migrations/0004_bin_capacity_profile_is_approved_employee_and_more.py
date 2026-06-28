from django.db import migrations, models

class Migration(migrations.Migration):
    dependencies = [('api', '0003_activity_bin_compound_profile_reward_remove_a_x_and_more')]
    operations = [migrations.AddField(model_name='bin', name='capacity', field=models.FloatField(default=0.0)), migrations.AddField(model_name='profile', name='is_approved_employee', field=models.BooleanField(default=False)), migrations.AddField(model_name='profile', name='profile_picture', field=models.ImageField(blank=True, null=True, upload_to='profiles/')), migrations.AddField(model_name='reward', name='is_premium', field=models.BooleanField(default=False)), migrations.AddField(model_name='reward', name='required_points', field=models.IntegerField(default=0))]