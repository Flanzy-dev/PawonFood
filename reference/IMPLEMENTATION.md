
ROLE

You are a senior full-stack engineer specializing in computer vision, multimodal AI integration, food safety UX, and production-ready web applications.

CONTEXT

I am developing PawonFood, a hyperlocal community food-rescue platform. Read the existing PRD and repository before making changes.

The core sharing flow is:

1. Capture a food photo using the camera.
2. Validate the image and classify the food.
3. Review the detected category and listing details.
4. Publish the listing.
5. Allow nearby receivers to reserve and collect the food.

The existing PRD defines three relevant MVP categories:

- "bahan_mentah"
- "makanan_matang"
- "bukan_makanan"

The PRD describes on-device YOLO validation. The current UI may contain simulated flows and mock data. Do not assume a working backend exists.

I want to extend the existing AI photo validation feature using a cloud-hosted Qwen vision-language model. The model should identify food, describe visible signs of deterioration, assess image quality, and return structured results.

TASK

Implement this feature incrementally within the existing PawonFood codebase.

Phase 1 — Repository audit

- Inspect the PRD, project structure, existing camera flow, YOLO implementation, category mapping, listing models, and current validation states.
- Identify what is functional versus simulated.
- Produce a concise implementation plan referencing actual files.
- Do not rewrite the application or introduce a new architecture unnecessarily.

Phase 2 — Validation contract

Define a typed validation response with:

- "is_food"
- "category"
- "food_name"
- "visual_condition"
- "visible_signs"
- "image_quality"
- "warnings"
- "listing_eligible"
- "reason"

Use the existing category conventions where possible. Validate every response on the server.

Phase 3 — Backend integration

- Use the existing backend if one exists; otherwise propose the smallest appropriate backend addition.
- Create a secure food-validation endpoint.
- Integrate a supported cloud Qwen vision model through a server-side API client.
- Store API credentials in environment variables.
- Validate uploaded image type, size, and dimensions.
- Add request timeouts, safe error handling, rate limiting, and structured logging.
- Do not expose API keys or sensitive provider errors to the client.
- Do not store images permanently unless the existing requirements explicitly require it.

Phase 4 — AI behavior

Instruct Qwen to:

- Identify the visible food and appropriate category.
- Report only visual observations supported by the image.
- Identify visible mold, discoloration, bruising, wilting, or other relevant signs when present.
- Flag ambiguous or low-quality images.
- Avoid fabricated confidence percentages, expiry dates, and claims about unseen internal conditions.
- Never guarantee that food is safe to consume based on a photograph.

Keep visual assessment separate from listing eligibility. A backend rules layer must validate the model response before deciding whether the listing can proceed.

Phase 5 — Existing UI integration

- Preserve the existing PawonFood design system and camera-first, three-step sharing flow.
- Reuse existing components wherever practical.
- Show loading, success, inconclusive, rejected, and retry states.
- Allow category correction where consistent with the PRD.
- Preserve portion, pricing, pickup deadline, pickup point, and provider guarantee fields.
- Prevent publication when validation fails or required checks are incomplete.
- Handle network and API failures without falsely marking food as validated.

Phase 6 — Testing and documentation

Add tests for:

- Valid food images and supported categories.
- Non-food objects.
- Blurry or invalid images.
- Model timeouts and malformed responses.
- Unexpected model categories.
- Listing eligibility and manual category corrections.
- API key protection and upload validation.

Document environment variables, local setup, the cloud API configuration, deployment steps, and known limitations.

CONSTRAINTS

- Treat the existing PRD as the source of truth.
- Inspect before editing.
- Do not replace working YOLO functionality without justification.
- Do not fabricate model capabilities or claim unverified accuracy.
- Do not hardcode API credentials.
- Do not automatically approve a listing when the model or backend fails.
- Do not present visual inspection as food-safety certification.
- Keep changes focused, maintainable, typed, and testable.
- Do not introduce unrelated features or replace mock integrations unless required by this task.
- Run relevant tests and lint/type checks, and report actual results.
- If essential infrastructure or credentials are missing, implement the integration boundary and document the required configuration instead of inventing successful API calls.

DELIVERABLES

1. Repository audit findings.
2. Implementation plan.
3. Code changes integrated into the existing application.
4. Tests and test results.
5. Environment configuration example without secrets.
6. Setup and deployment documentation.
7. Remaining limitations and recommended next steps.

Begin by auditing the repository and reporting the concrete files and integration points you found. Then implement the smallest complete vertical slice before expanding functionality.
