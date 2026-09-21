import { LightningElement, track, api } from 'lwc';
import fetchArchivePage from '@salesforce/apex/ArchiveDataController.fetchPage';
import script from '@salesforce/resourceUrl/MathScript'

export default class DynamicDataTable extends LightningElement {
    // Public API
    @api cardTitle = 'Archived Data Viewer';
    @api defaultPageSize = 50;

    // State
    @track columns = [];
    @track pageData = [];
    @track operatorOptions = [
        { label: 'Equals', value: 'equals' },
        { label: 'Contains', value: 'contains' },
        { label: 'Starts With', value: 'startsWith' }
    ];
    @track filterFieldOptions = [];

    objectName = '';
    pageNumber = 1;
    pageSize = this.defaultPageSize;
    totalRecords = 0;

    sortedBy;
    sortedDirection = 'asc';

    isLoading = false;
    errorMessage;

    // Filter UI state
    showFilter = false;
    filter = { field: null, operator: 'equals', value: '' };

    // Derived UI helpers for template (avoid expressions in HTML attributes)
    get isObjectNameEmpty() {
        return !this.objectName || this.objectName.trim().length === 0;
    }
    get isFirstPage() {
        return this.pageNumber <= 1;
    }
    get pageCount() {
        if (!this.totalRecords || !this.pageSize) return 0;
        return Math.ceil(this.totalRecords / this.pageSize);
    }
    get isLastPage() {
        return this.pageNumber >= this.pageCount;
    }
    // Template-safe disabled states (no inline boolean operators in HTML)
    get isLoadDisabled() {
        return this.isLoading || this.isObjectNameEmpty;
    }
    get isPrevDisabled() {
        return this.isLoading || this.isFirstPage;
    }
    get isNextDisabled() {
        return this.isLoading || this.isLastPage;
    }

    // Input handlers
    handleObjectNameChange = (e) => {
        this.objectName = e.detail.value;
    };

    handleLoad = () => {
        // Reset pagination and filters on fresh load
        this.pageNumber = 1;
        this.sortedBy = undefined;
        this.sortedDirection = 'asc';
        this.filter = { field: null, operator: 'equals', value: '' };
        this.fetchPageFromServer();
    };

    // Pagination
    handlePrev = () => {
        if (this.isFirstPage) return;
        this.pageNumber -= 1;
        this.fetchPageFromServer();
    };

    handleNext = () => {
        if (this.isLastPage) return;
        this.pageNumber += 1;
        this.fetchPageFromServer();
    };

    // Sorting (client-side on currently loaded page)
    handleSort = (event) => {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedBy = sortedBy;
        this.sortedDirection = sortDirection;
        if (!this.pageData || !this.pageData.length) return;
        const isAsc = sortDirection === 'asc';
        const data = [...this.pageData];
        data.sort((a, b) => {
            const v1 = a[sortedBy];
            const v2 = b[sortedBy];
            if (v1 === v2) return 0;
            if (v1 === undefined || v1 === null) return isAsc ? -1 : 1;
            if (v2 === undefined || v2 === null) return isAsc ? 1 : -1;
            if (typeof v1 === 'number' && typeof v2 === 'number') {
                return isAsc ? v1 - v2 : v2 - v1;
            }
            const s1 = String(v1).toLowerCase();
            const s2 = String(v2).toLowerCase();
            return isAsc ? (s1 > s2 ? 1 : -1) : (s1 > s2 ? -1 : 1);
        });
        this.pageData = data;
    };

    // Filter popover actions
    openFilterForField(fieldApiName) {
        this.filter = { ...this.filter, field: fieldApiName };
        this.showFilter = true;
    }
    closeFilter = () => {
        this.showFilter = false;
    };
    handleOperatorChange = (e) => {
        this.filter = { ...this.filter, operator: e.detail.value };
    };
    handleFilterValueChange = (e) => {
        this.filter = { ...this.filter, value: e.detail.value };
    };
    clearFilter = () => {
        this.filter = { field: null, operator: 'equals', value: '' };
        this.pageNumber = 1;
        this.fetchPageFromServer();
        this.showFilter = false;
    };
    applyFilter = () => {
        this.pageNumber = 1;
        this.fetchPageFromServer();
        this.showFilter = false;
    };

    // Build datatable columns from metadata fields
    buildColumnsFromMetadata(fields) {
        if (!Array.isArray(fields)) {
            this.columns = [];
            return;
        }
        // Build picklist options for filter field selector
        this.filterFieldOptions = (fields || []).map((f) => ({
            label: f.label || f.name,
            value: f.name
        }));

        const cols = fields.map((f) => {
            const base = {
                label: f.label || f.name,
                fieldName: f.name,
                sortable: f.sortable || true
            };
            switch ((f.type || '').toLowerCase()) {
                case 'string':
                case 'id':
                    return { ...base, type: 'text' };
                case 'boolean':
                    return { ...base, type: 'boolean' };
                case 'date':
                    return { ...base, type: 'date' };
                case 'datetime':
                    return { ...base, type: 'date', typeAttributes: { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' } };
                case 'number':
                    return { ...base, type: 'number', typeAttributes: { maximumFractionDigits: 2 } };
                case 'currency':
                    return { ...base, type: 'currency', typeAttributes: { currencyCode: 'USD' } };
                case 'picklist':
                    return { ...base, type: 'text' };
                case 'reference':
                    // Expect backend to add companion fields e.g., OwnerUrl & OwnerName
                    return {
                        ...base,
                        type: 'url',
                        fieldName: `${f.name}Url`,
                        typeAttributes: {
                            label: { fieldName: `${f.name}Name` },
                            target: '_blank'
                        }
                    };
                default:
                    return { ...base, type: 'text' };
            }
        });

        // Add filter action icons in column labels via actions slot is not available; instead we can add onheaderclick handlers by wrapping header outside datatable.
        // As a pragmatic approach, provide a small header toolbar outside for active column filter state.
        this.columns = cols;
    }

    // Filter toolbar wiring
    handleFilterFieldPick = (e) => {
        this.filter = { ...this.filter, field: e.detail.value || null };
    };
    openFilter = () => {
        if (!this.filter.field) {
            this.errorMessage = 'Select a filter field first.';
            return;
        }
        this.showFilter = true;
    };

    // Server call
    async fetchPageFromServer() {
        if (!this.objectName) {
            this.errorMessage = 'Provide an Object API Name.';
            return;
        }
        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            const req = {
                objectName: this.objectName,
                pageNumber: this.pageNumber,
                pageSize: this.pageSize,
                filters: this.filter.field && this.filter.value ? [{ field: this.filter.field, operator: this.filter.operator, value: this.filter.value }] : [],
                sortSpec: this.sortedBy ? { field: this.sortedBy, direction: this.sortedDirection } : null
            };
            const resp = await fetchArchivePage({ requestJson: JSON.stringify(req) });

            // Expect: { fields: [...], records: [...], totalRecords: n, pageNumber, pageSize }
            if (!resp) {
                throw new Error('Empty response from server');
            }
            const { fields, records, totalRecords, pageNumber, pageSize } = resp;

            // Rebuild columns when fields change
            // Fields are nested inside objectInfo in the response
            const fieldsFromResp = resp.objectInfo && resp.objectInfo.fields ? resp.objectInfo.fields : fields;
            this.buildColumnsFromMetadata(fieldsFromResp);

            // Apply any display shaping for reference types if backend provided raw ids only
            // Assumption: backend already provided *Url and *Name for references if present

            this.pageData = Array.isArray(records) ? records : [];
            this.totalRecords = Number(totalRecords || 0);
            if (pageNumber) this.pageNumber = pageNumber;
            if (pageSize) this.pageSize = pageSize;

            // Re-apply client sort on current page if set
            if (this.sortedBy) {
                this.handleSort({ detail: { fieldName: this.sortedBy, sortDirection: this.sortedDirection } });
            }
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error(e);
            this.errorMessage = (e && e.body && e.body.message) || e.message || 'Unknown error';
        } finally {
            this.isLoading = false;
        }
    }
}