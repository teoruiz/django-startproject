# Domain notes

Django owns models, invariants, permissions, workflows and authorization. Document decisions here before implementation.
For each domain, capture vocabulary, actors, allowed actions, invariants and unresolved questions.
The starter intentionally has no sample business domain. Identity lives in `core.User`, extends Django's user,
and has a unique login email. Frontend route checks are presentation, never business authorization.
