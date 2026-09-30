"""Central names prevent hard-coded environments in notebooks and jobs."""
from dataclasses import dataclass


@dataclass(frozen=True)
class LakehouseConfig:
    catalog: str
    bronze_schema: str = "bronze"
    silver_schema: str = "silver"
    gold_schema: str = "gold"

    def table(self, layer: str, name: str) -> str:
        return f"{self.catalog}.{getattr(self, f'{layer}_schema')}.{name}"
