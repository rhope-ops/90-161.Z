# Handing over the 90-161.Z flows

For a publications manager who takes over the 6 flows of the solution "90-161.Z flows" when the person who imported them leaves or moves. The list of flows is in [power-automate-provisioning.md](power-automate-provisioning.md) section 5. The roles are in [roles-and-permissions.md](roles-and-permissions.md). This page adds no publishing rule; DAFMAN 90-161 stays the only rule source.

Decision: the Administrator chose "S9 A" on 19 Nov 26 (a handover runbook and a co-owner on each flow now; see [DECISIONS.md](DECISIONS.md) and [the S9 text](reviews/2026-11-13-sweep-decisions.md)).

## 1. What "owner" and "co-owner" mean

- The owner of a flow is the person whose account the flow runs under. Each flow uses the owner's sign-in for its connections to SharePoint and to Outlook.
- A co-owner is a second person who can open, edit, turn on and turn off the same flow. A co-owner does not change whose connections the flow uses.
- If the only owner's account is disabled, the connections of that account stop working, so the flows stop. A co-owner keeps the flows reachable, so someone can switch them to their own connections. This is the reason for the co-owner (S9 text: "At PCS or leave the flows stop").
- Source: the S9 text, and Microsoft Learn, "Create a cloud flow in a solution" (flows you co-own appear on the "Shared with me" tab).

## 2. Before you leave: add a co-owner to each flow

Do this now, and again whenever a flow is added to the solution. The round card "Add a second owner to each app flow" in [scripts/paste_bundles.json](../scripts/paste_bundles.json) holds the proven steps. Round R32 proved adding and removing a second owner on one flow ([R32 results](reviews/2026-11-18-r32-results.md), finding 5).

1. Ask a person in your office to agree to be the co-owner.
2. Open the Power Automate site for your environment.
3. On the left, select "Solutions" (it can be under "More").
4. Select the solution "90-161.Z flows".
5. Select the first flow whose name starts with "90161Z F01".
6. Select "Share" at the top.
7. In the box under "Owners", type the name of the person.
8. Select that person in the list.
9. Select the Back arrow at the top left to return to the solution.
10. Repeat steps 5 to 9 for F02, F03, F04, F05 and F06.
11. If there is no "Share": on the card "Co-owners", select "Edit".
12. If a panel about connections opens: select "OK".

Not proven on the gov device: adding the co-owner to all 6 flows (R32 proved one flow), and that the co-owner can then edit and turn on the flows.

## 3. When a new person takes over: the connections

Every flow uses two connection references (source: [scripts/build_flow_solution.py](../scripts/build_flow_solution.py) and the files in [flow/solution/defs](../flow/solution/defs)):

| Flow | SharePoint | Outlook (sends e-mail) |
|---|---|---|
| F01 Activity Log | yes | yes |
| F02 Next Review Due | yes | yes |
| F03 Suspense Reminders | yes | yes |
| F04 Status Report | yes | yes |
| F05 Endorsement Routing | yes | yes |
| F06 Hold and Resume | yes | yes |

The solution holds one connection reference for SharePoint and one for Outlook, shared by all flows, so you set each of the two once. The plan in [roles-and-permissions.md](roles-and-permissions.md) (continuity, P5A) is the same: a co-owner opens the solution and sets each connection reference to their own connection without the original owner.

Steps for the new person (you must be a co-owner first; if you are not, ask the site owner or a remaining co-owner to add you, as in section 2). All steps in this section are not proven on the gov device:

1. Open the Power Automate site and select "Solutions" on the left.
2. Select the solution "90-161.Z flows".
3. Find the connection reference for SharePoint in the solution's list of objects.
4. Open it and choose your own SharePoint connection. If you have none, create one and sign in with your own account.
5. Do the same for the connection reference for Outlook.
6. If a flow shows "Fix connection" instead, select it and sign in with your own account (Microsoft Learn, "Manage connections in Power Automate").
7. Turn on any flow that reads Off.
8. Tell the other co-owners that the flows now run under your account.

If a step fails, write down only the line that starts with "Error" (no names, no session ID) and ask the Administrator.

## 4. After the swap: check

Use the round card "Check the flows and their connections" (proven in R32, finding 1: 6 flows On, no connection warning).

1. Open the solution "90-161.Z flows".
2. Count the flows that read On in the column "Status". The 6 flows of this runbook must all read On. (The solution may also hold 2 test flows, "T21"; they are not part of this check.)
3. Select one flow, for example "90161Z F02 Next Review Due r3".
4. Look at the card "Connections" for a yellow or red mark or the words "Fix connection". There must be none.
5. Run the status report once, as the round card "Run two of the flows by hand" does: select the flow "90161Z F04 Status Report r3", select "Run", type your work e-mail address in the box "Send the report to (e-mail)", select "Run flow".
6. Wait 2 minutes. Open your Inbox (or "Junk Email") and look for an e-mail whose subject starts with "TEST MODE".
7. If it came to you, the Outlook connection works and the SharePoint connection read the lists.

Proven in R32 on the original owner's account; not proven on the gov device for a new owner's connections.

## 5. Not proven yet on the gov device

- Adding a co-owner to all 6 flows (only one flow was proven).
- That a co-owner can edit and turn on a flow while the original owner's account is disabled.
- Choosing a new SharePoint or Outlook connection in the connection references, the screen words for it, and that the flows then run under the new account.
- That rows made by the flows after the swap show the new person as creator (the S9 text says every flow-made row is created by the owner).
- That the status report e-mail test works under a new owner's connections.
- Removing the original owner after the swap.
- Creating a new connection reference in this environment: R32 finding 3 shows that a new solution or a hand-made flow fails with "The connections could not be loaded", so do not make new flows or import a new solution as part of a handover; keep to the existing solution.

## Sources

- This repo: [DECISIONS.md](DECISIONS.md) (19 Nov 26, S9 A); [S9 text](reviews/2026-11-13-sweep-decisions.md); [R32 results](reviews/2026-11-18-r32-results.md) findings 1, 3 and 5; the round cards in [scripts/paste_bundles.json](../scripts/paste_bundles.json); [scripts/build_flow_solution.py](../scripts/build_flow_solution.py); [roles-and-permissions.md](roles-and-permissions.md).
- Microsoft Learn: "Create a cloud flow in a solution" (https://learn.microsoft.com/power-automate/create-flow-solution); "Manage connections in Power Automate" (https://learn.microsoft.com/power-automate/add-manage-connections); "Power Automate US Government" (https://learn.microsoft.com/power-automate/us-govt).
