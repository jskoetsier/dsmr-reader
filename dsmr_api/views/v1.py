import logging

from django.http.response import (
    HttpResponse,
    HttpResponseBadRequest,
    HttpResponseForbidden,
    HttpResponseNotAllowed,
    HttpResponseServerError,
)
from django.views.generic.base import View
from ratelimit.decorators import ratelimit

import dsmr_datalogger.services.datalogger
from dsmr_api.forms import DsmrReadingForm
from dsmr_api.models import APISettings
from dsmr_datalogger.exceptions import InvalidTelegramError

logger = logging.getLogger("dsmrreader")


class DataloggerDsmrReading(View):
    @ratelimit(key="ip", rate="100/h", method="POST")
    @ratelimit(key="header:HTTP_X_AUTHKEY", rate="1000/h", method="POST")
    def post(self, request):
        api_settings = APISettings.get_solo()

        if not api_settings.allow:
            return HttpResponseNotAllowed(
                permitted_methods=["POST"], content="API is disabled"
            )

        if request.META.get(
            "HTTP_X_AUTHKEY"
        ) != api_settings.auth_key and request.META.get(
            "HTTP_AUTHORIZATION"
        ) != "Token {}".format(
            api_settings.auth_key
        ):
            return HttpResponseForbidden(content="Invalid auth key")

        post_form = DsmrReadingForm(request.POST)

        if not post_form.is_valid():
            logger.warning("API validation failed with POST data: %s", request.POST)
            return HttpResponseBadRequest("Invalid data")

        dsmr_reading = None

        try:
            dsmr_reading = dsmr_datalogger.services.datalogger.telegram_to_reading(
                data=post_form.cleaned_data["telegram"]
            )
        except InvalidTelegramError:
            # The service called already logs the error.
            pass

        if not dsmr_reading:
            return HttpResponseServerError(content="Failed to parse telegram")

        return HttpResponse(status=201)
