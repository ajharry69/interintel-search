from django.db import models


class Author(models.Model):
    name = models.CharField(max_length=100)
    email = models.EmailField()

    def __str__(self):
        return self.name


class Book(models.Model):
    title = models.CharField(max_length=255)
    intro = models.TextField()
    authors = models.ManyToManyField(Author)

    def __str__(self):
        return self.title
