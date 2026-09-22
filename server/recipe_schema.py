from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


ActivityType = Literal[
    'prep', 'chop', 'mix', 'heat', 'bake', 'wait', 'timer', 'plate', 'complete'
]


class RecipeFields(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, allow_inf_nan=False)


class IngredientOutput(RecipeFields):
    name: str = Field(min_length=1)
    quantity: float | None = Field(default=None, ge=0)
    unit: Literal['g', 'kg', 'ml', 'l', 'tsp', 'tbsp', 'cup', 'pcs'] | None = None
    note: str | None = None


class ToolOutput(RecipeFields):
    name: str = Field(min_length=1)
    quantity: int | None = Field(default=None, ge=0)


class StepOutput(RecipeFields):
    instruction: str = Field(min_length=1)
    activityType: ActivityType
    heat: str | None = None
    time: int | None = Field(default=None, ge=0, description='Duration in seconds')
    seasoning: str | None = None
    notes: str | None = None
    whatToLookFor: str


class RecipeOutput(RecipeFields):
    name: str = Field(min_length=1)
    category: Literal['breakfast', 'lunch', 'dinner', 'dessert', 'drinks', 'lazy meals']
    tags: list[Literal[
        'quick', 'healthy', 'budget', 'comfort', 'spicy', 'vegetarian',
        'high-protein', 'light', 'kid-friendly', 'one-pot', 'no-cook',
        'meal-prep', 'breakfast', 'lunch', 'dinner', 'dessert', 'drink',
    ]] = Field(min_length=1, max_length=5)
    ingredients: list[IngredientOutput] = Field(min_length=1)
    tools: list[ToolOutput]
    steps: list[StepOutput] = Field(min_length=1)
