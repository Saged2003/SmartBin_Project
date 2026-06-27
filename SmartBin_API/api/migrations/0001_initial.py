
import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='b',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('z', models.CharField(max_length=50, unique=True)),
                ('v', models.IntegerField()),
                ('w', models.FloatField(default=0.0)),
                ('t', models.CharField(default='plastic', max_length=50)),
                ('j', models.BooleanField(default=False)),
            ],
        ),
        migrations.CreateModel(
            name='o',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('n', models.CharField(max_length=100)),
                ('s', models.CharField(max_length=200)),
                ('a', models.FloatField(blank=True, null=True)),
                ('z', models.FloatField(blank=True, null=True)),
                ('v', models.FloatField(default=0.0)),
                ('h', models.CharField(default='available', max_length=50)),
            ],
        ),
        migrations.CreateModel(
            name='r',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('n', models.CharField(max_length=100)),
                ('s', models.CharField(max_length=100)),
                ('v', models.IntegerField()),
                ('j', models.BooleanField(default=True)),
            ],
        ),
        migrations.CreateModel(
            name='a',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('t', models.CharField(max_length=50)),
                ('w', models.FloatField()),
                ('v', models.IntegerField()),
                ('q', models.DateTimeField(auto_now_add=True)),
                ('x', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
        ),
        migrations.CreateModel(
            name='p',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('y', models.IntegerField(default=0)),
                ('w', models.FloatField(default=0.0)),
                ('c', models.IntegerField(default=0)),
                ('x', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, to=settings.AUTH_USER_MODEL)),
            ],
        ),
    ]
