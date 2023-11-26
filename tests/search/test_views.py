from django.test import TestCase
from django.urls import reverse

from tests.factories import AuthorFactory, BookFactory


class SearchViewTestCase(TestCase):
    def setUp(self):
        self.john_doe = AuthorFactory(name="John Doe")
        self.jane_doe = AuthorFactory(name="John Doe")
        self.science_encyclopedia = BookFactory(
            title="Science encyclopedia",
            intro="Random introduction content from science encyclopedia",
        )
        self.science_encyclopedia.authors.add(self.john_doe)
        self.mathematics_encyclopedia = BookFactory(
            title="Mathematics encyclopedia",
            intro="Random introduction content from Mathematics encyclopedia",
        )
        self.science_encyclopedia.authors.add(self.john_doe, self.jane_doe)

    def test_should_return_200_and_not_include_books_data_in_context(self):
        path = reverse("search:index")
        response = self.client.get(path)

        assert response.status_code == 200
        assert response.context["query"] == ""
        assert "books" not in response.context
        assert "total_books_count" not in response.context

    def test_should_return_200_and_include_books_data_in_context(self):
        path = reverse("search:index")
        response = self.client.get(path, data={"q": "science"})

        assert response.status_code == 200
        assert response.context["query"] == "science"
        books = response.context["books"]
        assert [rt["title"] for rt in books.values("rank", "title")] == ["Science encyclopedia"]
        assert response.context["total_books_count"] == 2
