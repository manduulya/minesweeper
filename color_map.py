"""
Generates world_colored.svg from world.svg.
Uses a greedy graph coloring algorithm so no two bordering countries share the same color.
Run once from the project root:  python color_map.py
"""

import re

# ---------------------------------------------------------------------------
# 4 colors that look great on the dark #0B1E3D ocean background
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Dark mode — all countries start as unrevealed (same dark colour).
# Colours are applied at runtime in Dart after the player wins a country.
# ---------------------------------------------------------------------------
DARK_MODE   = True
OCEAN_COLOR = "#0B1E3D"   # dark navy ocean
COUNTRY_DARK = "#75848e"  # blue-grey unrevealed countries
BORDER_COLOR = "#556470"  # borders (slightly darker than country)

# Palette kept for reference / non-dark-mode use
PALETTE = [
    "#FFFF00",  # neon yellow
    "#FF0066",  # neon pink
    "#00FF41",  # neon green
    "#BF00FF",  # neon violet
]

# ---------------------------------------------------------------------------
# Country adjacency list (borders).
# Keys and values are ISO 3166-1 alpha-2 codes matching the SVG id attributes.
# ---------------------------------------------------------------------------
ADJACENCY = {
    "AF": ["CN","IR","PK","TJ","TM","UZ"],
    "AL": ["GR","ME","MK","RS","XK"],
    "DZ": ["LY","MA","MR","ML","NE","TN","EH"],
    "AO": ["CG","CD","ZM","NA"],
    "AR": ["BO","BR","CL","PY","UY"],
    "AM": ["AZ","GE","IR","TR"],
    "AT": ["CH","CZ","DE","HU","IT","LI","SI","SK"],
    "AZ": ["AM","GE","IR","RU","TR"],
    "BH": ["QA","SA"],
    "BD": ["IN","MM"],
    "BY": ["LT","LV","PL","RU","UA"],
    "BE": ["DE","FR","LU","NL"],
    "BZ": ["GT","MX"],
    "BJ": ["BF","GH","NE","NG","TG"],
    "BT": ["CN","IN"],
    "BO": ["AR","BR","CL","PE","PY"],
    "BA": ["HR","ME","RS"],
    "BW": ["NA","ZA","ZM","ZW"],
    "BR": ["AR","BO","CO","GF","GY","PE","PY","SR","UY","VE"],
    "BN": ["MY"],
    "BG": ["GR","MK","RO","RS","TR"],
    "BF": ["BJ","CI","GH","ML","NE","TG"],
    "BI": ["CD","RW","TZ"],
    "KH": ["LA","TH","VN"],
    "CM": ["CF","CG","GA","GQ","NG","TD"],
    "CA": ["US"],
    "CF": ["CM","CD","CG","SD","SS","TD"],
    "TD": ["CM","CF","LY","NE","NG","SD"],
    "CL": ["AR","BO","PE"],
    "CN": ["AF","BT","IN","KZ","KG","LA","MN","MM","NP","PK","RU","TJ","VN"],
    "CO": ["BR","EC","PA","PE","VE"],
    "CG": ["AO","CM","CF","CD","GA"],
    "CD": ["AO","BI","CF","CG","RW","SS","TZ","UG","ZM"],
    "CR": ["NI","PA"],
    "CI": ["BF","GH","GN","LR","ML"],
    "HR": ["BA","HU","ME","RS","SI"],
    "CU": [""],
    "CZ": ["AT","DE","PL","SK"],
    "DK": ["DE"],
    "DJ": ["ER","ET","SO"],
    "DO": ["HT"],
    "EC": ["CO","PE"],
    "EG": ["IL","LY","SD"],
    "SV": ["GT","HN"],
    "GQ": ["CM","GA"],
    "ER": ["DJ","ET","SD"],
    "EE": ["LV","RU"],
    "ET": ["DJ","ER","KE","SO","SS","SD"],
    "FI": ["NO","RU","SE"],
    "FR": ["BE","DE","IT","LU","MC","ES","CH"],
    "GA": ["CM","CG","GQ"],
    "DE": ["AT","BE","CZ","DK","FR","LU","NL","PL","CH"],
    "GH": ["BF","CI","TG"],
    "GR": ["AL","BG","MK","TR"],
    "GT": ["BZ","HN","MX","NI","SV"],
    "GN": ["CI","GW","LR","ML","SN","SL"],
    "GW": ["GN","SN"],
    "GY": ["BR","SR","VE"],
    "HT": ["DO"],
    "HN": ["GT","NI","SV"],
    "HU": ["AT","HR","RO","RS","SK","SI","UA"],
    "IN": ["BD","BT","CN","MM","NP","PK"],
    "ID": ["MY","PG","TL"],
    "IR": ["AF","AM","AZ","IQ","PK","TR","TM"],
    "IQ": ["IR","JO","KW","SA","SY","TR"],
    "IE": ["GB"],
    "IL": ["EG","JO","LB","PS","SY"],
    "IT": ["AT","FR","SI","CH"],
    "JO": ["IQ","IL","SA","SY"],
    "KZ": ["CN","KG","RU","TM","UZ"],
    "KE": ["ET","SO","SS","TZ","UG"],
    "KP": ["CN","KR","RU"],
    "KR": ["KP"],
    "KW": ["IQ","SA"],
    "KG": ["CN","KZ","TJ","UZ"],
    "LA": ["CN","KH","MM","TH","VN"],
    "LV": ["BY","EE","LT","RU"],
    "LB": ["IL","SY"],
    "LS": ["ZA"],
    "LR": ["CI","GN","SL"],
    "LY": ["DZ","EG","NE","SD","TN","TD"],
    "LT": ["BY","LV","PL","RU"],
    "LU": ["BE","DE","FR"],
    "MK": ["AL","BG","GR","RS","XK"],
    "MG": [""],
    "MW": ["MZ","TZ","ZM"],
    "MY": ["BN","ID","TH"],
    "ML": ["DZ","BF","CI","GN","MR","NE","SN"],
    "MR": ["DZ","ML","SN","EH"],
    "MX": ["BZ","GT","US"],
    "MD": ["RO","UA"],
    "MN": ["CN","RU"],
    "ME": ["AL","BA","HR","RS","XK"],
    "MA": ["DZ","EH","ES"],
    "MZ": ["MW","ZA","SZ","TZ","ZM","ZW"],
    "MM": ["BD","CN","IN","LA","TH"],
    "NA": ["AO","BW","ZA","ZM"],
    "NP": ["CN","IN"],
    "NL": ["BE","DE"],
    "NZ": [""],
    "NI": ["CR","GT","HN"],
    "NE": ["DZ","BJ","BF","LY","ML","NG","TD"],
    "NG": ["BJ","CM","NE","TD"],
    "NO": ["FI","RU","SE"],
    "OM": ["SA","AE","YE"],
    "PK": ["AF","CN","IN","IR"],
    "PA": ["CO","CR"],
    "PG": ["ID"],
    "PY": ["AR","BO","BR"],
    "PE": ["BO","BR","CL","CO","EC"],
    "PH": [""],
    "PL": ["BY","CZ","DE","LT","RU","SK","UA"],
    "PT": ["ES"],
    "QA": ["SA"],
    "RO": ["BG","HU","MD","RS","UA"],
    "RU": ["AZ","BY","CN","EE","FI","GE","KZ","KP","LV","LT","MN","NO","PL","UA"],
    "RW": ["BI","CD","TZ","UG"],
    "SA": ["IQ","JO","KW","OM","QA","AE","YE"],
    "SN": ["GM","GN","GW","ML","MR"],
    "RS": ["AL","BA","BG","HR","HU","MK","ME","RO","XK"],
    "SL": ["GN","LR"],
    "SO": ["DJ","ET","KE"],
    "ZA": ["BW","LS","MZ","NA","SZ","ZW"],
    "SS": ["CF","CD","ET","KE","SD","UG"],
    "ES": ["AD","FR","PT","MA"],
    "SD": ["CF","EG","ER","ET","LY","SS","TD"],
    "SR": ["BR","GY"],
    "SZ": ["MZ","ZA"],
    "SE": ["FI","NO"],
    "CH": ["AT","FR","DE","IT","LI"],
    "SY": ["IQ","IL","JO","LB","TR"],
    "TW": [""],
    "TJ": ["AF","CN","KG","UZ"],
    "TZ": ["BI","CD","KE","MW","MZ","RW","UG","ZM"],
    "TH": ["KH","LA","MY","MM"],
    "TL": ["ID"],
    "TG": ["BJ","BF","GH"],
    "TN": ["DZ","LY"],
    "TR": ["AM","AZ","BG","GE","GR","IQ","IR","SY"],
    "TM": ["AF","IR","KZ","UZ"],
    "UG": ["CD","KE","RW","SS","TZ"],
    "UA": ["BY","HU","MD","PL","RO","RU","SK"],
    "AE": ["OM","SA"],
    "GB": ["IE"],
    "US": ["CA","MX"],
    "UY": ["AR","BR"],
    "UZ": ["AF","KZ","KG","TJ","TM"],
    "VE": ["BR","CO","GY"],
    "VN": ["CN","KH","LA"],
    "EH": ["DZ","MA","MR"],
    "YE": ["OM","SA"],
    "ZM": ["AO","BW","CD","MW","MZ","NA","TZ","ZW"],
    "ZW": ["BW","MZ","ZA","ZM"],
    "XK": ["AL","MK","ME","RS"],
    "PS": ["IL","EG"],
    "GF": ["BR","SR"],
    "AU": [],
    "JP": [],
    "GL": [],
    "IS": [],
    "NZ": [],
    "PH": [],
    "TW": [],
    "MG": [],
    "CU": [],
    # Caribbean & Atlantic islands
    "BS": [],
    "KY": [],
    "AG": [],
    "KN": [],
    "TT": [],
    "TC": [],
    "VI": [],
    "GP": [],
    "PR": [],
    "BB": [],
    "LC": [],
    "VC": [],
    "GD": [],
    "DM": [],
    "JM": [],
    "MQ": [],
    # Pacific & Indian Ocean islands
    "AS": [],
    "FJ": [],
    "FM": [],
    "MP": [],
    "NC": [],
    "PF": [],
    "SB": [],
    "TO": [],
    "VU": [],
    "WS": [],
    # Other island nations
    "CV": [],
    "KM": [],
    "MU": [],
    "SC": [],
    "ST": [],
    "MT": [],
    "CY": [],
    "FK": [],
    "FO": [],
}

# Multi-path countries use class instead of id in the SVG
CLASS_TO_ISO = {
    "Angola":              "AO",
    "Argentina":           "AR",
    "Australia":           "AU",
    "Azerbaijan":          "AZ",
    "Canada":              "CA",
    "Chile":               "CL",
    "China":               "CN",
    "Denmark":             "DK",
    "France":              "FR",
    "Greece":              "GR",
    "Indonesia":           "ID",
    "Italy":               "IT",
    "Japan":               "JP",
    "Malaysia":            "MY",
    "Norway":              "NO",
    "Oman":                "OM",
    "Papua New Guinea":    "PG",
    "Philippines":         "PH",
    "Russian Federation":  "RU",
    "Turkey":              "TR",
    "United Kingdom":      "GB",
    "United States":       "US",
    "New Zealand":         "NZ",
    "Greenland":           "GL",
    "Iceland":             "IS",
    "Falkland Islands":    "FK",
    "Faeroe Islands":      "FO",
    "Canary Islands (Spain)": "ES",
    "American Samoa":      "AS",
    "Antigua and Barbuda": "AG",
    "Bahamas":             "BS",
    "Comoros":             "KM",
    "Cape Verde":          "CV",
    "Cayman Islands":      "KY",
    "Cyprus":              "CY",
    "Federated States of Micronesia": "FM",
    "Falkland Islands":    "FK",
    "French Polynesia":    "PF",
    "Fiji":                "FJ",
    "Guadeloupe":          "GP",
    "New Caledonia":       "NC",
    "Northern Mariana Islands": "MP",
    "Puerto Rico":         "PR",
    "Saint Kitts and Nevis": "KN",
    "Sao Tome and Principe": "ST",
    "São Tomé and Principe": "ST",
    "Malta":               "MT",
    "Seychelles":          "SC",
    "Solomon Islands":     "SB",
    "Samoa":               "WS",
    "Tonga":               "TO",
    "Trinidad and Tobago": "TT",
    "Turks and Caicos Islands": "TC",
    "United States Virgin Islands": "VI",
    "Vanuatu":             "VU",
    "Mauritius":           "MU",
}

# ---------------------------------------------------------------------------
# Greedy graph coloring
# ---------------------------------------------------------------------------
def greedy_color(adjacency, palette):
    all_countries = set(adjacency.keys())
    # also add countries that appear only as neighbors
    for neighbors in adjacency.values():
        all_countries.update(neighbors)
    all_countries.discard("")

    # Pre-seed large/dominant countries to preferred colors
    color_map = {
        "RU": "#BF00FF",
        "CN": "#FF0066",
        "US": "#FF0066",
        "BR": "#00FF41",
        "AU": "#FFFF00",
    }
    for country in sorted(all_countries):
        if country in color_map:
            continue  # already pre-seeded
        neighbor_colors = set()
        for neighbor in adjacency.get(country, []):
            if neighbor in color_map:
                neighbor_colors.add(color_map[neighbor])
        for color in palette:
            if color not in neighbor_colors:
                color_map[country] = color
                break
        else:
            # fallback: just pick first color
            color_map[country] = palette[0]

    # In dark mode all countries get the same unrevealed colour (overrides coloring)
    if DARK_MODE:
        for iso in list(color_map.keys()):
            color_map[iso] = COUNTRY_DARK

    return color_map

# ---------------------------------------------------------------------------
# Patch the SVG
# ---------------------------------------------------------------------------
def patch_svg(input_path, output_path, color_map):
    with open(input_path, "r", encoding="utf-8") as f:
        svg = f.read()

    # Ocean background
    svg = svg.replace('fill="#ececec"', f'fill="{OCEAN_COLOR}"')

    # Inject background rect for the ocean
    bg_rect = f'<rect width="2000" height="857" fill="{OCEAN_COLOR}"/>'
    svg = re.sub(r'(<svg\b[^>]*>)', r'\1' + bg_rect, svg, count=1)

    # Process each <path ...> block
    def replace_path(m):
        tag = m.group(0)

        # Determine ISO code
        iso = None

        # 1. Try id="XX"
        id_match = re.search(r'\bid="([^"]+)"', tag)
        if id_match:
            iso = id_match.group(1).upper()

        # 2. Try class="CountryName"
        if not iso:
            class_match = re.search(r'\bclass="([^"]+)"', tag)
            if class_match:
                cls = class_match.group(1)
                iso = CLASS_TO_ISO.get(cls, "").upper() or None

        if iso and iso in color_map:
            fill = color_map[iso]
            # Replace existing fill or add it
            if re.search(r'\bfill="', tag):
                tag = re.sub(r'\bfill="[^"]*"', f'fill="{fill}"', tag)
            else:
                tag = tag.replace("<path", f'<path fill="{fill}"', 1)
        elif DARK_MODE:
            # Any path not in color_map (e.g. lakes, territories) also gets dark
            if re.search(r'\bfill="', tag):
                tag = re.sub(r'\bfill="[^"]*"', f'fill="{COUNTRY_DARK}"', tag)
            else:
                tag = tag.replace("<path", f'<path fill="{COUNTRY_DARK}"', 1)

        return tag

    svg = re.sub(r"<path\b[^>]*/?>", replace_path, svg, flags=re.DOTALL)

    # Borders
    svg = re.sub(r'\bstroke="[^"]*"', f'stroke="{BORDER_COLOR}"', svg)
    svg = re.sub(r'\bstroke-width="[^"]*"', 'stroke-width=".5"', svg)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(svg)

    print(f"Done! Saved to {output_path}")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    color_map = greedy_color(ADJACENCY, PALETTE)

    print(f"Colored {len(color_map)} countries")
    print("Sample assignments:")
    for iso in ["US", "CA", "MX", "FR", "DE", "NG", "CN", "AU", "BR"]:
        print(f"  {iso}: {color_map.get(iso, 'NOT FOUND')}")

    patch_svg(
        input_path="assets/world.svg",
        output_path="assets/world_colored.svg",
        color_map=color_map,
    )

    # Export PNG for the 3-D globe texture (requires: pip install svglib reportlab)
    try:
        from svglib.svglib import svg2rlg
        from reportlab.graphics import renderPM

        drawing = svg2rlg("assets/world_colored.svg")
        if drawing is None:
            raise RuntimeError("svg2rlg returned None")

        # Scale to 2048 x 1024
        scale_x = 2048 / drawing.width
        scale_y = 1024 / drawing.height
        drawing.width  = 2048
        drawing.height = 1024
        drawing.transform = (scale_x, 0, 0, scale_y, 0, 0)

        renderPM.drawToFile(drawing, "assets/world_map.png", fmt="PNG")
        print("Globe texture saved to assets/world_map.png (2048x1024)")
    except ImportError:
        print("\nPNG texture not generated.")
        print("Install dependencies and re-run:  pip install svglib reportlab")
