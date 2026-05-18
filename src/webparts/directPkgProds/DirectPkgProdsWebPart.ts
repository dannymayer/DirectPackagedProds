import { Version } from '@microsoft/sp-core-library';
import {
  BaseClientSideWebPart,
  IPropertyPaneConfiguration,
  PropertyPaneTextField,
} from '@microsoft/sp-webpart-base';
import { AadHttpClient } from '@microsoft/sp-http';
import * as React from 'react';
import * as ReactDom from 'react-dom';

import DirectPkgProds, { IDirectPkgProdsProps } from './components/DirectPkgProds';
import { DppApiService } from './services/DppApiService';

export interface IDirectPkgProdsWebPartProps {
  /** Base URL of the Azure Function App, e.g. https://my-func.azurewebsites.net */
  apiBaseUrl: string;
}

/**
 * SPFx entry point for the Direct Packaged Products web part.
 *
 * On initialisation it acquires an AadHttpClient scoped to the Function App's
 * AAD application URI so that every API call carries the user's access token.
 * All permission decisions happen server-side in the Azure Functions API — the
 * web part never makes any permission-related decisions itself.
 */
export default class DirectPkgProdsWebPart extends BaseClientSideWebPart<IDirectPkgProdsWebPartProps> {
  private apiService: DppApiService | undefined;

  public async onInit(): Promise<void> {
    await super.onInit();

    const baseUrl = (this.properties.apiBaseUrl || '').replace(/\/$/, '');
    if (baseUrl) {
      // AadHttpClientFactory uses the resource URI (the Function App's AAD
      // application ID URI) to determine which token to request.
      const aadClient: AadHttpClient =
        await this.context.aadHttpClientFactory.getClient(baseUrl);
      this.apiService = new DppApiService(baseUrl, aadClient);
    }
  }

  public render(): void {
    const element: React.ReactElement<IDirectPkgProdsProps> = React.createElement(
      DirectPkgProds,
      {
        apiService: this.apiService,
        isConfigured: !!this.properties.apiBaseUrl,
      },
    );
    ReactDom.render(element, this.domElement);
  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse('1.0');
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          header: {
            description: 'Configure the Direct Packaged Products web part',
          },
          groups: [
            {
              groupName: 'API Configuration',
              groupFields: [
                PropertyPaneTextField('apiBaseUrl', {
                  label: 'Azure Function App Base URL',
                  description:
                    'Enter the base URL of the deployed Function App, ' +
                    'e.g. https://dpp-functions.azurewebsites.net',
                  placeholder: 'https://your-function-app.azurewebsites.net',
                }),
              ],
            },
          ],
        },
      ],
    };
  }
}
