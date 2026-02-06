"""Weather MCP Server.

Provides real-time weather data via OpenWeatherMap API.
Includes mock data fallback when no API key is configured.
"""

from __future__ import annotations

import os
import random
from typing import Any, Literal

import httpx
from fastmcp import FastMCP
from pydantic import BaseModel

# Transport type for FastMCP
Transport = Literal["stdio", "sse", "http", "streamable-http"]

# Initialize FastMCP server
mcp = FastMCP(
    name="weather-mcp",
)

# Configuration
API_KEY = os.getenv("OPENWEATHERMAP_API_KEY", "")
BASE_URL = "https://api.openweathermap.org/data/2.5"
GEO_URL = "https://api.openweathermap.org/geo/1.0"
TIMEOUT = 30.0

# Type definitions
Units = Literal["metric", "imperial", "standard"]


class CurrentWeather(BaseModel):
    """Current weather data model."""

    location: str
    country: str
    temperature: float
    feels_like: float
    humidity: int
    pressure: int
    description: str
    wind_speed: float
    wind_direction: int
    clouds: int
    visibility: int
    units: str


class ForecastDay(BaseModel):
    """Single forecast day data model."""

    date: str
    temperature_min: float
    temperature_max: float
    humidity: int
    description: str
    wind_speed: float
    precipitation_probability: float


class Location(BaseModel):
    """Location search result model."""

    name: str
    country: str
    state: str | None
    latitude: float
    longitude: float


def _use_mock_data() -> bool:
    """Check if we should use mock data (no API key configured)."""
    return not API_KEY


def _get_mock_current_weather(location: str, units: Units) -> CurrentWeather:
    """Generate mock current weather data (uses random for demo purposes)."""
    temp_base = 20.0 if units == "metric" else 68.0 if units == "imperial" else 293.0
    unit_label = "C" if units == "metric" else "F" if units == "imperial" else "K"

    return CurrentWeather(
        location=location.title(),
        country="MOCK",
        temperature=round(temp_base + random.uniform(-10, 10), 1),  # noqa: S311
        feels_like=round(temp_base + random.uniform(-12, 8), 1),  # noqa: S311
        humidity=random.randint(30, 90),  # noqa: S311
        pressure=random.randint(1000, 1030),  # noqa: S311
        description=random.choice(  # noqa: S311
            ["clear sky", "few clouds", "scattered clouds", "light rain", "sunny"]
        ),
        wind_speed=round(random.uniform(0, 15), 1),  # noqa: S311
        wind_direction=random.randint(0, 360),  # noqa: S311
        clouds=random.randint(0, 100),  # noqa: S311
        visibility=random.randint(5000, 10000),  # noqa: S311
        units=unit_label,
    )


def _get_mock_forecast(location: str, days: int, units: Units) -> list[ForecastDay]:
    """Generate mock forecast data (uses random for demo purposes)."""
    from datetime import datetime, timedelta

    forecasts = []
    temp_base = 20.0 if units == "metric" else 68.0 if units == "imperial" else 293.0

    for i in range(days):
        date = datetime.now() + timedelta(days=i + 1)
        forecasts.append(
            ForecastDay(
                date=date.strftime("%Y-%m-%d"),
                temperature_min=round(temp_base + random.uniform(-15, 0), 1),  # noqa: S311
                temperature_max=round(temp_base + random.uniform(0, 15), 1),  # noqa: S311
                humidity=random.randint(30, 90),  # noqa: S311
                description=random.choice(  # noqa: S311
                    [
                        "clear sky",
                        "partly cloudy",
                        "cloudy",
                        "light rain",
                        "thunderstorm",
                    ]
                ),
                wind_speed=round(random.uniform(0, 20), 1),  # noqa: S311
                precipitation_probability=round(random.uniform(0, 1), 2),  # noqa: S311
            )
        )
    return forecasts


def _get_mock_locations(query: str) -> list[Location]:
    """Generate mock location search results (uses random for demo purposes)."""
    return [
        Location(
            name=query.title(),
            country="US",
            state="California",
            latitude=34.0522 + random.uniform(-1, 1),  # noqa: S311
            longitude=-118.2437 + random.uniform(-1, 1),  # noqa: S311
        ),
        Location(
            name=f"{query.title()} City",
            country="UK",
            state=None,
            latitude=51.5074 + random.uniform(-1, 1),  # noqa: S311
            longitude=-0.1278 + random.uniform(-1, 1),  # noqa: S311
        ),
    ]


@mcp.tool()
async def get_current(
    location: str,
    units: Units = "metric",
) -> dict[str, Any]:
    """Get current weather for a location.

    Args:
        location: City name, optionally with country code
            (e.g., "London" or "London,UK")
        units: Temperature units - "metric" (Celsius), "imperial" (Fahrenheit),
            or "standard" (Kelvin)

    Returns:
        Current weather data including temperature, humidity, wind, and conditions.
        Note: Returns mock data if OPENWEATHERMAP_API_KEY is not configured.
    """
    if _use_mock_data():
        return _get_mock_current_weather(location, units).model_dump()

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        response = await client.get(
            f"{BASE_URL}/weather",
            params={
                "q": location,
                "appid": API_KEY,
                "units": units,
            },
        )
        response.raise_for_status()
        data = response.json()

        unit_label = "C" if units == "metric" else "F" if units == "imperial" else "K"

        return CurrentWeather(
            location=data["name"],
            country=data["sys"]["country"],
            temperature=data["main"]["temp"],
            feels_like=data["main"]["feels_like"],
            humidity=data["main"]["humidity"],
            pressure=data["main"]["pressure"],
            description=data["weather"][0]["description"],
            wind_speed=data["wind"]["speed"],
            wind_direction=data["wind"].get("deg", 0),
            clouds=data["clouds"]["all"],
            visibility=data.get("visibility", 10000),
            units=unit_label,
        ).model_dump()


@mcp.tool()
async def get_forecast(
    location: str,
    days: int = 5,
    units: Units = "metric",
) -> list[dict[str, Any]]:
    """Get weather forecast for a location.

    Args:
        location: City name, optionally with country code
            (e.g., "Paris" or "Paris,FR")
        days: Number of forecast days (1-5, default 5)
        units: Temperature units - "metric" (Celsius), "imperial" (Fahrenheit),
            or "standard" (Kelvin)

    Returns:
        List of daily forecasts with min/max temperatures, conditions,
        and precipitation probability.
        Note: Returns mock data if OPENWEATHERMAP_API_KEY is not configured.
    """
    days = max(1, min(days, 5))  # Clamp to 1-5 days

    if _use_mock_data():
        return [f.model_dump() for f in _get_mock_forecast(location, days, units)]

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        response = await client.get(
            f"{BASE_URL}/forecast",
            params={
                "q": location,
                "appid": API_KEY,
                "units": units,
                "cnt": days * 8,  # 8 data points per day (3-hour intervals)
            },
        )
        response.raise_for_status()
        data = response.json()

        # Aggregate 3-hour forecasts into daily forecasts
        daily: dict[str, dict[str, Any]] = {}
        for item in data["list"]:
            date = item["dt_txt"].split(" ")[0]
            if date not in daily:
                daily[date] = {
                    "temps": [],
                    "humidity": [],
                    "descriptions": [],
                    "wind_speeds": [],
                    "pop": [],
                }
            daily[date]["temps"].append(item["main"]["temp"])
            daily[date]["humidity"].append(item["main"]["humidity"])
            daily[date]["descriptions"].append(item["weather"][0]["description"])
            daily[date]["wind_speeds"].append(item["wind"]["speed"])
            daily[date]["pop"].append(item.get("pop", 0))

        forecasts = []
        for date, values in list(daily.items())[:days]:
            forecasts.append(
                ForecastDay(
                    date=date,
                    temperature_min=round(min(values["temps"]), 1),
                    temperature_max=round(max(values["temps"]), 1),
                    humidity=round(sum(values["humidity"]) / len(values["humidity"])),
                    description=max(
                        set(values["descriptions"]),
                        key=values["descriptions"].count,
                    ),
                    wind_speed=round(
                        sum(values["wind_speeds"]) / len(values["wind_speeds"]), 1
                    ),
                    precipitation_probability=round(max(values["pop"]), 2),
                ).model_dump()
            )

        return forecasts


@mcp.tool()
async def search_location(query: str) -> list[dict[str, Any]]:
    """Search for location coordinates by name.

    Args:
        query: Location name to search for (e.g., "Tokyo", "New York")

    Returns:
        List of matching locations with name, country, state, latitude, and longitude.
        Note: Returns mock data if OPENWEATHERMAP_API_KEY is not configured.
    """
    if _use_mock_data():
        return [loc.model_dump() for loc in _get_mock_locations(query)]

    async with httpx.AsyncClient(timeout=TIMEOUT) as client:
        response = await client.get(
            f"{GEO_URL}/direct",
            params={
                "q": query,
                "appid": API_KEY,
                "limit": 5,
            },
        )
        response.raise_for_status()
        data = response.json()

        return [
            Location(
                name=item["name"],
                country=item["country"],
                state=item.get("state"),
                latitude=item["lat"],
                longitude=item["lon"],
            ).model_dump()
            for item in data
        ]


if __name__ == "__main__":
    transport: Transport = "streamable-http"
    transport_env = os.getenv("MCP_TRANSPORT", "streamable-http")
    if transport_env in ("stdio", "sse", "http", "streamable-http"):
        transport = transport_env  # type: ignore[assignment]
    port = int(os.getenv("MCP_PORT", "8002"))
    host = os.getenv("MCP_HOST", "0.0.0.0")  # noqa: S104 - bind all interfaces for Docker

    if _use_mock_data():
        print("WARNING: OPENWEATHERMAP_API_KEY not set, using mock data")

    mcp.run(transport=transport, host=host, port=port)
