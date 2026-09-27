pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    property string preferredScreenName: ""
    property var leases: []
    property bool stopped: false
    property bool synchronizing: false

    function registerHost(host, objects) {
        if (stopped || synchronizing)
            return;
        synchronizing = true;
        const next = [];
        for (let index = 0; index < leases.length; index++) {
            const lease = leases[index];
            if (!lease.handler || (lease.host === host && objects.indexOf(lease.handler) === -1))
                lease.retire();
            else
                next.push(lease);
        }
        for (let index = 0; index < objects.length; index++) {
            const handler = objects[index];
            if (!(handler instanceof IpcHandler) || !handler.enabled || !handler.target)
                continue;
            if (next.some(lease => lease.handler === handler))
                continue;
            next.push(leaseComponent.createObject(root, {
                handler: handler,
                host: host,
                targetName: handler.target
            }));
        }
        leases = next;
        synchronizing = false;
        reconcile();
    }

    function unregisterHost(host) {
        synchronizing = true;
        const retained = [];
        for (let index = 0; index < leases.length; index++) {
            const lease = leases[index];
            if (lease.host === host || !lease.handler) {
                lease.retire();
            } else {
                retained.push(lease);
            }
        }
        leases = retained;
        synchronizing = false;
        reconcile();
    }

    function reconcile() {
        if (stopped || synchronizing)
            return;
        synchronizing = true;
        // Release every old owner before registering any replacement.
        const winners = ({});
        for (let index = 0; index < leases.length; index++) {
            const lease = leases[index];
            lease.blocked = true;
            if (!lease.handler || !lease.host)
                continue;
            const key = lease.targetName;
            const previous = winners[key];
            if (!previous || (lease.host.screenName === preferredScreenName && previous.host.screenName !== preferredScreenName))
                winners[key] = lease;
        }
        for (const key in winners)
            winners[key].blocked = false;
        synchronizing = false;
    }

    function shutdown() {
        stopped = true;
        for (let index = 0; index < leases.length; index++)
            leases[index].retire();
        leases = [];
    }

    onPreferredScreenNameChanged: reconcile()

    Component {
        id: leaseComponent
        Item {
            id: lease
            required property var handler
            required property var host
            required property string targetName
            property bool blocked: true

            function retire() {
                blocked = true;
                enabledOverride.restoreMode = Binding.RestoreNone;
                destroy();
            }

            Binding {
                id: enabledOverride
                target: lease.handler
                property: "enabled"
                when: lease.blocked
                value: false
                restoreMode: Binding.RestoreBindingOrValue
            }
            Connections {
                target: lease.handler
                function onTargetChanged() {
                    lease.targetName = lease.handler.target;
                    root.reconcile();
                }
            }
            Connections {
                target: lease.host
                function onScreenNameChanged() {
                    root.reconcile();
                }
            }
        }
    }
}
