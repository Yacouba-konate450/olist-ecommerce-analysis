"""Download the Olist Brazilian E-Commerce dataset into data/.

Same files as the Kaggle dataset "Brazilian E-Commerce Public Dataset by Olist",
fetched from Olist's public GitHub repository (no Kaggle account needed).
"""
from pathlib import Path
from urllib.request import urlretrieve

BASE = "https://raw.githubusercontent.com/olist/work-at-olist-data/master/datasets/"
FILES = [
    "olist_orders_dataset.csv", "olist_customers_dataset.csv", "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv", "olist_order_reviews_dataset.csv", "olist_products_dataset.csv",
    "olist_sellers_dataset.csv", "product_category_name_translation.csv",
]
Path("data").mkdir(exist_ok=True)
for f in FILES:
    print("downloading", f)
    urlretrieve(BASE + f, Path("data") / f)
print("done")
