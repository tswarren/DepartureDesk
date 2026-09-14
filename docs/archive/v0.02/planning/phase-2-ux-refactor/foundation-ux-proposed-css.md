/* Persistent Sidebar Layout Frame */
.dd-app-shell {
    display: grid;
    min-height: 100vh;
    grid-template-columns: 16rem 1fr;
  }
  
  .dd-sidebar {
    display: flex;
    flex-direction: column;
    background: var(--dd-navy);
    color: var(--dd-text-on-dark);
    padding: 1.25rem 1rem;
  }
  
  /* Metric Card Layout with Icon Circle */
  .dd-metric-card {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem;
    border: 1px solid var(--dd-border);
    border-radius: var(--dd-radius-md);
    background: var(--dd-surface);
  }
  
  .dd-metric-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2.75rem;
    height: 2.75rem;
    border-radius: 999px;
    background: var(--dd-surface-emphasis);
    color: var(--dd-teal);
  }
  
  /* Collection Filter Toolbar */
  .dd-filter-bar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.75rem;
    margin-bottom: 1rem;
  }
  
  /* Table Progress Bars */
  .dd-progress {
    height: 0.5rem;
    width: 6rem;
    border-radius: 999px;
    background: var(--dd-surface-subtle);
    overflow: hidden;
  }
  
  .dd-progress-bar {
    height: 100%;
    background: var(--dd-teal);
    border-radius: 999px;
  }
  
  
  
  
  Icons
  <!-- app/views/shared/icons/_calendar_blank.html.erb -->
  <svg xmlns="http://www.w3.org/2000/svg" 
       viewBox="0 0 256 256" 
       fill="none" 
       stroke="currentColor" 
       stroke-linecap="round" 
       stroke-linejoin="round" 
       stroke-width="16" 
       class="<%= local_assigns[:class] %>" 
       aria-hidden="true">
    <!-- Insert Phosphor path data here -->
  </svg>
  
  
  
  