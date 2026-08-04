// Current conditions for the morning brief. Open-Meteo stays the source of truth
// for forecast numbers (hard rule 6), needs no key, and the WMO mapping below
// mirrors WeatherCondition.displayText in Shared/Models/WeatherCondition.swift.

const BASE_URL = "https://api.open-meteo.com/v1/forecast";

export type TemperatureUnit = "fahrenheit" | "celsius";

export interface CurrentConditions {
  /** Already formatted for display, e.g. "72°". */
  temperature: string;
  condition: string;
}

/** Mirrors WeatherCondition(fromWMO:).displayText. */
export function conditionText(code: number): string {
  if (code === 0) return "Clear";
  if (code === 1 || code === 2) return "Mainly Clear";
  if (code === 3) return "Overcast";
  if (code === 45 || code === 48) return "Fog";
  if (code >= 51 && code <= 55) return "Drizzle";
  if (code >= 61 && code <= 65) return "Rain";
  if (code === 66 || code === 67) return "Sleet";
  if (code >= 71 && code <= 75) return "Snow";
  if (code === 77) return "Snow Grains";
  if (code >= 80 && code <= 82) return "Rain Showers";
  if (code === 85 || code === 86) return "Snow Showers";
  if (code === 95 || code === 96 || code === 99) return "Thunderstorm";
  return "Variable";
}

interface ForecastResponse {
  current?: {
    temperature_2m?: number;
    weather_code?: number;
  };
}

export async function fetchCurrentConditions(
  latitude: number,
  longitude: number,
  unit: TemperatureUnit,
  fetchImpl: typeof fetch = fetch,
): Promise<CurrentConditions | null> {
  const url =
    `${BASE_URL}?latitude=${latitude}&longitude=${longitude}` +
    `&current=temperature_2m,weather_code&temperature_unit=${unit}`;

  const response = await fetchImpl(url);
  if (!response.ok) return null;

  const body = (await response.json()) as ForecastResponse;
  const temperature = body.current?.temperature_2m;
  const code = body.current?.weather_code;
  if (temperature === undefined || code === undefined) return null;

  return {
    temperature: `${Math.round(temperature)}°`,
    condition: conditionText(code),
  };
}
