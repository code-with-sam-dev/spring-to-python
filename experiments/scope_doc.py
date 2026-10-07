"""What the installed FastAPI says about Depends(scope=...).

The words are FastAPI's own; each bullet is reflowed to fit
a terminal frame.
"""
import inspect
import textwrap

import fastapi
from fastapi import param_functions

src = inspect.getsource(param_functions.Depends)
start = src.index('* `"function"`')
end = src.index("Read more about it", start)
print(f"FastAPI {fastapi.__version__}, Depends(scope=...):")
for bullet in inspect.cleandoc(src[start:end]).split("\n* "):
    text = " ".join(bullet.lstrip("* ").split())
    print(textwrap.fill(text, 66, initial_indent="* ",
                        subsequent_indent="  "))
