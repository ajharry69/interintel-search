from django.contrib.postgres.search import SearchQuery, SearchRank, SearchVector, SearchHeadline
from django.views.generic import TemplateView

from interintel.search.models import Book


class SearchView(TemplateView):
    template_name = "index.html"

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        q = self.request.GET.get("q") or ""
        context["query"] = q
        if q:
            vector = (
                    SearchVector("title", weight="A")
                    + SearchVector("intro", weight="B")
                    + SearchVector("authors__name", weight="C")
            )

            query = SearchQuery(value=q)
            objects = Book.objects
            context["books"] = (
                objects.annotate(
                    rank=SearchRank(vector=vector, query=query),
                    intro_highlight=SearchHeadline(
                        "title",
                        query=query,
                        start_sel="""<span class="highlight">""",
                        stop_sel="</span>",
                    ),
                )
                .prefetch_related("authors")
                .filter(rank__gt=0.01)
                .distinct("pk", "rank")
                .order_by("-rank")
            )
            context["total_books_count"] = objects.count()
        return context
