# User Stories

## Notebook Management
- **Create notebook**
  - Given I open the app
  - When I tap “New Notebook”
  - Then I can enter a title
  - And the notebook appears in the list

- **Rename notebook**
  - Given I have a notebook
  - When I tap “Rename”
  - Then I can change its title
  - And the change is saved

- **Delete notebook**
  - Given I have one or more notebooks
  - When I swipe left on a notebook and confirm delete
  - Then it disappears from the list

---

## Page Management
- **Add page**
  - Given I am inside a notebook
  - When I tap “Add Page”
  - Then a new blank page appears

- **Delete page**
  - Given I have multiple pages
  - When I delete one
  - Then it is removed and the rest remain intact

- **Reorder pages**
  - Given I have several pages
  - When I drag a page in the list
  - Then the order updates immediately

---

## Drawing and Writing
- **Draw**
  - Given I have opened a page
  - When I draw with Apple Pencil
  - Then lines appear smoothly
  - And the drawing is saved automatically

- **Undo/Redo**
  - Given I have drawn strokes
  - When I tap undo
  - Then the last stroke disappears
  - When I tap redo
  - Then the stroke reappears

---

## Backgrounds
- **Select background**
  - Given I am on a page
  - When I choose a background (grid, lined, or custom image)
  - Then it replaces the old background
  - And I can continue drawing on top
