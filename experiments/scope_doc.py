"""What the installed FastAPI says about Depends(scope=...)."""
import inspect

import fastapi
from fastapi import param_functions

src = inspect.getsource(param_functions.Depends)
start = src.index('* `"function"`')
end = src.index("Read more about it", start)
print(f"FastAPI {fastapi.__version__}, Depends(scope=...):")
print(inspect.cleandoc(src[start:end]))
