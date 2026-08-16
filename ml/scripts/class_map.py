"""Canonical class map for RAASTA M2 + M5 (11 classes)."""



CLASS_NAMES = [

    "pothole",

    "crack",

    "speed_bump",

    "person",

    "cow",

    "buffalo",

    "dog",

    "cat",

    "horse",

    "donkey",

    "goat",

]



CLASS_TO_ID = {name: i for i, name in enumerate(CLASS_NAMES)}



# Map messy dataset labels → our canonical names.

LABEL_ALIASES = {

    # pothole

    "pothole": "pothole",

    "potholes": "pothole",

    "pot hole": "pothole",

    "pot-hole": "pothole",

    "d40": "pothole",

    "D40": "pothole",

    "hole": "pothole",

    # crack

    "crack": "crack",

    "cracks": "crack",

    "d00": "crack",

    "d10": "crack",

    "d20": "crack",

    "D00": "crack",

    "D10": "crack",

    "D20": "crack",

    "longitudinal crack": "crack",

    "longitudinal": "crack",

    "transverse crack": "crack",

    "transverse": "crack",

    "alligator crack": "crack",

    "alligator": "crack",

    # speed bump

    "speed_bump": "speed_bump",

    "speed-bump": "speed_bump",

    "speedbump": "speed_bump",

    "speed bump": "speed_bump",

    "speed breaker": "speed_bump",

    "speed-breaker": "speed_bump",

    "speedbreaker": "speed_bump",

    "bump": "speed_bump",

    "hump": "speed_bump",

    "speed hump": "speed_bump",

    "unmarked bump": "speed_bump",

    "unmarked": "speed_bump",

    # person

    "person": "person",

    "pedestrian": "person",

    "people": "person",

    "human": "person",

    "man": "person",

    "woman": "person",

    "child": "person",

    # cow

    "cow": "cow",

    "cattle": "cow",

    "ox": "cow",

    # buffalo

    "buffalo": "buffalo",

    "buffallo": "buffalo",

    "water buffalo": "buffalo",

    # dog / cat

    "dog": "dog",

    "cat": "cat",

    # horse / donkey

    "horse": "horse",

    "donkey": "donkey",

    "ass": "donkey",

    "mule": "donkey",

    # goat (do NOT map sheep→goat anymore; skip sheep)

    "goat": "goat",

}





def canonical_name(raw: str) -> str | None:

    key = raw.strip()

    if key in LABEL_ALIASES:

        return LABEL_ALIASES[key]

    lower = key.lower().replace("_", " ").replace("-", " ").strip()

    if lower in LABEL_ALIASES:

        return LABEL_ALIASES[lower]

    for alias, canon in LABEL_ALIASES.items():

        if alias.lower().replace("_", " ").replace("-", " ") == lower:

            return canon

    return None


