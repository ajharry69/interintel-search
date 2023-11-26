import factory

from interintel.search.models import Author, Book

__all__ = ["AuthorFactory", "BookFactory"]


class AuthorFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Author
        django_get_or_create = ("email",)

    name = factory.Sequence(lambda n: f"Name{n + 1} Name{n + 1}")
    email = factory.Sequence(lambda n: f"user{n + 1}@example.com")


class BookFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Book
        django_get_or_create = ("title",)

    title = factory.Sequence(lambda n: f"Encyclopedia {n + 1}")
    intro = factory.Sequence(lambda n: f"Sample intro {n + 1}")
